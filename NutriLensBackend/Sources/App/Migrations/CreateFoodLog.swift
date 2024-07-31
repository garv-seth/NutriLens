import Fluent

struct CreateFoodLog: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("food_logs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("food_name", .string, .required)
            .field("calories", .int, .required)
            .field("date", .datetime, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("food_logs").delete()
    }
}
