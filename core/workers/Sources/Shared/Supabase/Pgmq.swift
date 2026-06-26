// PGMQ helpers: Supabase message-queue (pgmq) read/send extensions.
import Supabase
import Foundation

public extension SupabaseClient {
    func pgmqGet<T: Decodable>(
        queue: String,
        n: Int = 1,
        sleep: Int = 60,
        as type: T.Type
    ) async throws -> QueueMessage<T> {
        let tasks: [QueueMessage<T>] = try await schema("pgmq_public")
            .rpc("read", params: [
                "queue_name": queue,
                "sleep_seconds": String(sleep),
                "n": String(n)
            ])
            .execute()
            .value


        guard let task = tasks.first else {
           throw NSError(
                domain: "supabase.pgmq.get_task",
                code: 1666,
                userInfo: [NSLocalizedDescriptionKey: "No task available"]
            )
        }

        return task
    }

    func pgmqAck(
        queue: String,
        msgId: Int
    ) async throws {
        _ = try await schema("pgmq_public")
            .rpc("archive", params: [
                "queue_name": queue,
                "message_id": msgId.toString()
            ])
            .execute()
    }
}
