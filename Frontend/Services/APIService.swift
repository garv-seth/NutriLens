import Foundation
import Combine
import SwiftUI

class APIService {
    static let shared = APIService()
    private init() {}
    
    private let baseURL = ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://192.168.1.100:8080"
    private let gptAPIKey = ProcessInfo.processInfo.environment["GPT_API_KEY"] ?? ""

    private var cancellables: Set<AnyCancellable> = []

    func login(username: String, password: String) -> AnyPublisher<String, Error> {
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.serverError
                }
                return output.data
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .map { $0.token }
            .eraseToAnyPublisher()
    }
    
    func register(username: String, email: String, password: String) -> AnyPublisher<Void, Error> {
        print("Attempting to register user: \(username)")
        let url = URL(string: "\(baseURL)/register")!
        print("Registration URL: \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "email": email, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                print("Received response with status code: \((output.response as? HTTPURLResponse)?.statusCode ?? -1)")
                guard let response = output.response as? HTTPURLResponse else {
                    throw APIError.serverError
                }
                if response.statusCode == 200 {
                    return
                } else if response.statusCode == 409 {
                    throw APIError.userAlreadyExists
                } else {
                    throw APIError.serverError
                }
            }
            .mapError { error in
                print("Registration error: \(error)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    func fetchFoodLogs() -> AnyPublisher<[FoodLog], Error> {
        let url = URL(string: "\(baseURL)/food-logs")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(UserDefaults.standard.string(forKey: "accessToken") ?? "")", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.serverError
                }
                return output.data
            }
            .decode(type: [FoodLog].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    func createFoodLog(foodName: String, calories: Int, date: Date) -> AnyPublisher<Void, Error> {
        let url = URL(string: "\(baseURL)/food-logs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(UserDefaults.standard.string(forKey: "accessToken") ?? "")", forHTTPHeaderField: "Authorization")
        
        let foodLog = FoodLog(id: UUID(), foodName: foodName, calories: calories, date: date)
        request.httpBody = try? JSONEncoder().encode(foodLog)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 201 else {
                    throw APIError.serverError
                }
                return ()
            }
            .eraseToAnyPublisher()
    }

    func analyzeFood(image: UIImage) -> AnyPublisher<FoodAnalysis, Error> {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: APIError.invalidImageData).eraseToAnyPublisher()
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(gptAPIKey)", forHTTPHeaderField: "Authorization")

        let base64Image = imageData.base64EncodedString()
        let payload: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Analyze this food image and provide the following information: 1) Food name, 2) Estimated calories, 3) Nutritional breakdown (protein, carbs, fat), 4) Health insights. Format the response as JSON."],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ],
            "max_tokens": 300
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.serverError
                }
                return output.data
            }
            .decode(type: GPTResponse.self, decoder: JSONDecoder())
            .compactMap { response -> FoodAnalysis? in
                guard let content = response.choices.first?.message.content,
                      let data = content.data(using: .utf8),
                      let json = try? JSONDecoder().decode(FoodAnalysis.self, from: data) else {
                    return nil
                }
                return json
            }
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                }
                return error
            }
            .eraseToAnyPublisher()
    }

    func fetchUserProfile(token: String) -> AnyPublisher<User, Error> {
        let url = URL(string: "\(baseURL)/user-profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.serverError
                }
                return output.data
            }
            .decode(type: User.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    func fetchInsights(token: String) -> AnyPublisher<NutritionInsights, Error> {
        let url = URL(string: "\(baseURL)/insights")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw APIError.serverError
                }
                return output.data
            }
            .decode(type: NutritionInsights.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

struct LoginResponse: Codable {
    let token: String
}

struct GPTResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}

struct NutritionalBreakdown: Codable {
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum APIError: Error, LocalizedError {
    case serverError
    case invalidImageData
    case decodingError
    case userAlreadyExists

    var errorDescription: String? {
        switch self {
        case .serverError:
            return "An error occurred. Please try again later."
        case .invalidImageData:
            return "Invalid image data."
        case .decodingError:
            return "Error decoding data."
        case .userAlreadyExists:
            return "A user with this username or email already exists."
        }
    }
}
