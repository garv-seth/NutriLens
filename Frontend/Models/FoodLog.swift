import Foundation

struct FoodLog: Identifiable, Codable {
    var id: UUID
    var foodName: String
    var calories: Int
    var date: Date
}
