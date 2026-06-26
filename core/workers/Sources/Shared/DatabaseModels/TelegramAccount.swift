import Foundation
import Supabase

// Telegram user profile model
public struct TelegramAccount: Codable, Sendable {
    public let id: Int64
    public let first_name: String
    public let last_name: String?
    public let username: String?
    public let language_code: String?
    public let is_premium: Bool?
    public let photo_url: String?
    public let created_at: Date?
    public let updated_at: Date?

    public init(
        id: Int64,
        first_name: String,
        last_name: String? = nil,
        username: String? = nil,
        language_code: String? = nil,
        is_premium: Bool? = nil,
        photo_url: String? = nil,
        created_at: Date? = nil,
        updated_at: Date? = nil
    ) {
        self.id = id
        self.first_name = first_name
        self.last_name = last_name
        self.username = username
        self.language_code = language_code
        self.is_premium = is_premium
        self.photo_url = photo_url
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

public extension TelegramAccount {
    // Find or create user
    static func findOrCreate(supabase: SupabaseClient, telegramUser: TelegramUser) async throws -> Self {
        // First try to find
        if let existing = try await find(supabase: supabase, telegramId: telegramUser.id) {
            // Update user data in case of changes
            return try await existing.update(supabase: supabase, with: telegramUser)
        }

        // If not found — create
        return try await create(supabase: supabase, telegramUser: telegramUser)
    }

    // Find user by ID
    static func find(supabase: SupabaseClient, telegramId: Int64) async throws -> Self? {
        let result: [TelegramAccount] = try await supabase
            .from("telegram_accounts")
            .select()
            .eq("id", value: String(telegramId))
            .execute()
            .value

        return result.first
    }

    // Create a new user
    static func create(supabase: SupabaseClient, telegramUser: TelegramUser) async throws -> Self {
        let new = TelegramAccount(
            id: telegramUser.id,
            first_name: telegramUser.firstName,
            last_name: telegramUser.lastName,
            username: telegramUser.username,
            language_code: telegramUser.languageCode,
            is_premium: telegramUser.isPremium,
            photo_url: telegramUser.photoUrl,
            created_at: Date(),
            updated_at: Date()
        )

        return try await supabase
            .from("telegram_accounts")
            .insert(new)
            .select()
            .single()
            .execute()
            .value
    }

    // Update user data
    func update(supabase: SupabaseClient, with telegramUser: TelegramUser) async throws -> Self {
        let updated = TelegramAccount(
            id: telegramUser.id,
            first_name: telegramUser.firstName,
            last_name: telegramUser.lastName,
            username: telegramUser.username,
            language_code: telegramUser.languageCode,
            is_premium: telegramUser.isPremium,
            photo_url: telegramUser.photoUrl,
            created_at: self.created_at,
            updated_at: Date()
        )

        return try await supabase
            .from("telegram_accounts")
            .update(updated)
            .eq("id", value: String(telegramUser.id))
            .select()
            .single()
            .execute()
            .value
    }

    // Check device access
    func hasDevice(supabase: SupabaseClient, deviceId: String) async throws -> Bool {
        let result: [TelegramAccountDeviceRelation] = try await supabase
            .from("telegram_account_devices")
            .select()
            .eq("account_id", value: String(id))
            .eq("device_id", value: deviceId)
            .execute()
            .value

        return !result.isEmpty
    }

    // Add device
    func addDevice(supabase: SupabaseClient, deviceId: String) async throws {
        let relation = TelegramAccountDeviceRelation(
            account_id: id,
            device_id: deviceId
        )

        try await supabase
            .from("telegram_account_devices")
            .insert(relation)
            .execute()
    }

    // Get user's device IDs
    func getDeviceIds(supabase: SupabaseClient) async throws -> [String] {
        let relations: [TelegramAccountDeviceRelation] = try await supabase
            .from("telegram_account_devices")
            .select()
            .eq("account_id", value: String(id))
            .execute()
            .value

        return relations.map { $0.device_id }
    }
}

// Auxiliary struct for M2M relation
struct TelegramAccountDeviceRelation: Codable, Sendable {
    let account_id: Int64
    let device_id: String

    init(account_id: Int64, device_id: String) {
        self.account_id = account_id
        self.device_id = device_id
    }
}
