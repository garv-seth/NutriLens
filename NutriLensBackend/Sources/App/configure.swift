import Fluent
import FluentPostgresDriver
import Vapor

public func configure(_ app: Application) throws {
    // Update the deployment target
    #if os(iOS)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    #endif
    
    // Use the new configuration method
    let sqlConfig = SQLPostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "postgres",
        password: Environment.get("DATABASE_PASSWORD") ?? "g",
        database: Environment.get("DATABASE_NAME") ?? "nutrilens_db",
        tls: .prefer(try .init(configuration: .clientDefault))
    )
    
    app.databases.use(.postgres(configuration: sqlConfig), as: .psql)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateFoodLog())

    try routes(app)
}
