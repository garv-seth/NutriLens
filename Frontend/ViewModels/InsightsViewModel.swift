import Foundation
import Combine

class InsightsViewModel: ObservableObject {
    @Published var insights: NutritionInsights?
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func fetchInsights() {
        guard let token = UserDefaults.standard.string(forKey: "accessToken") else { return }

        apiService.fetchInsights(token: token)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Failed to fetch insights: \(error)")
                }
            } receiveValue: { [weak self] insights in
                self?.insights = insights
            }
            .store(in: &cancellables)
    }
}
