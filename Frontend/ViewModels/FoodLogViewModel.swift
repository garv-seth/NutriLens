import Foundation
import Combine

class FoodLogViewModel: ObservableObject {
    @Published var foodLogs: [FoodLog] = []
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func loadFoodLogs() {
        apiService.fetchFoodLogs()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Failed to load food logs: \(error)")
                }
            } receiveValue: { [weak self] logs in
                self?.foodLogs = logs
            }
            .store(in: &cancellables)
    }
}
