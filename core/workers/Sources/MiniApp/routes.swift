// MiniApp route registration.
import Vapor

func routes(_ app: Application) throws {

    app.get { req in
        return req.redirect(to: "/devices", redirectType: .permanent)
    }

    // Mini App routes
    try app.register(collection: MiniAppViewController())
}
