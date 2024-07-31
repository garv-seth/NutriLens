import Vapor
import Fluent

struct FoodLogController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let foodLogs = routes.grouped("food-logs")
        foodLogs.get(use: index)
        foodLogs.post(use: create)
        foodLogs.group(":foodLogID") { foodLog in
            foodLog.delete(use: delete)
        }
    }

    func index(req: Request) throws -> EventLoopFuture<[FoodLog]> {
        return FoodLog.query(on: req.db).all()
    }

    func create(req: Request) throws -> EventLoopFuture<FoodLog> {
        let foodLog = try req.content.decode(FoodLog.self)
        return foodLog.save(on: req.db).map { foodLog }
    }

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return FoodLog.find(req.parameters.get("foodLogID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
