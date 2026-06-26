// AppEventLoopGroup: shared NIO event loop group for workers.
import NIOPosix
import NIOHTTP1
import NIOCore

enum AppEventLoopGroup {
    static let shared = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    static func shutdown() {
        try? shared.syncShutdownGracefully()
    }
}
