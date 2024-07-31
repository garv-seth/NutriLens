import Fluent
import Vapor

final class FoodLog: Model, Content {
    static let schema = "food_logs"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "food_name")
    var foodName: String

    @Field(key: "calories")
    var calories: Int

    @Field(key: "date")
    var date: Date

    init() { }

    init(id: UUID? = nil, userID: User.IDValue, foodName: String, calories: Int, date: Date) {
        self.id = id
        self.$user.id = userID
        self.foodName = foodName
        self.calories = calories
        self.date = date
    }
}
