import Foundation

struct User: Codable, Identifiable {
    var id: UUID
    var username: String
    var dailyCalorieGoal: Int

    init(id: UUID = UUID(), username: String, dailyCalorieGoal: Int) {
        self.id = id
        self.username = username
        self.dailyCalorieGoal = dailyCalorieGoal
    }
}
