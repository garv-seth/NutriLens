import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "daily_calorie_goal")
    var dailyCalorieGoal: Int

    init() { }

    init(id: UUID? = nil, username: String, email: String, passwordHash: String, dailyCalorieGoal: Int = 2000) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.dailyCalorieGoal = dailyCalorieGoal
    }
    
}
