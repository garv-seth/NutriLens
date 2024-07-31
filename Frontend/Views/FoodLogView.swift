import SwiftUI

struct FoodLogView: View {
    @State private var foodLogs: [FoodLog] = []

    var body: some View {
        NavigationView {
            List(foodLogs) { log in
                VStack(alignment: .leading) {
                    Text(log.foodName)
                        .font(.headline)
                    Text("\(log.calories) calories")
                        .font(.subheadline)
                    Text(log.date, style: .date)
                }
            }
            .navigationTitle("Food Log")
        }
        .onAppear(perform: loadFoodLogs)
    }

    func loadFoodLogs() {
        // Here you would typically fetch food logs from your backend
        // For now, we'll use placeholder data
        foodLogs = [
            FoodLog(id: UUID(), foodName: "Apple", calories: 95, date: Date()),
            FoodLog(id: UUID(), foodName: "Banana", calories: 105, date: Date())
        ]
    }
}
