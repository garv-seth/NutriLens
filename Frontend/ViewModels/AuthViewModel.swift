import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User?
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init() {
        checkSavedToken()
    }

    func signIn(username: String, password: String) {
        apiService.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { token in
                UserDefaults.standard.set(token, forKey: "accessToken")
                self.isAuthenticated = true
                self.fetchUserProfile()
            }
            .store(in: &cancellables)
    }

    func signUp(username: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthViewModel: Attempting to sign up user")
        apiService.register(username: username, email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .finished:
                    print("AuthViewModel: Sign up finished successfully")
                    completion(.success(()))
                case .failure(let error):
                    print("AuthViewModel: Sign up failed with error: \(error)")
                    completion(.failure(error))
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    func signOut() {
        isAuthenticated = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "accessToken")
    }

    private func checkSavedToken() {
        if let token = UserDefaults.standard.string(forKey: "accessToken") {
            isAuthenticated = true
            fetchUserProfile()
        }
    }

    func fetchUserProfile() {
        guard let token = UserDefaults.standard.string(forKey: "accessToken") else { return }

        apiService.fetchUserProfile(token: token)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isAuthenticated = false
                    UserDefaults.standard.removeObject(forKey: "accessToken")
                }
            } receiveValue: { user in
                self.user = user
            }
            .store(in: &cancellables)
    }
}
