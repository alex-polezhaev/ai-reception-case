// DateUtils: date/time helpers (Moscow timezone, device-activity checks).
import Foundation

struct DateUtils {
    // Moscow time zone
    private static let moscowTimeZone = TimeZone(identifier: "Europe/Moscow")!
    static func isDeviceActive(_ lastActiveAt: Date?) -> Bool {
        guard let lastActiveAt = lastActiveAt else {
            return false
        }

        let now = Date()
        let inactiveThreshold: TimeInterval = 5 * 60 // 5 minutes
        return now.timeIntervalSince(lastActiveAt) < inactiveThreshold
    }

    static func formatLastActivity(_ lastActiveAt: Date?) -> String {
        guard let lastActiveAt = lastActiveAt else {
            return "Never active"
        }

        let now = Date()
        let timeInterval = now.timeIntervalSince(lastActiveAt)

        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) min ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) d ago"
        }
    }

    static func getCurrentDateString(daysAgo: Int = 0) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = moscowTimeZone
        var calendar = Calendar.current
        calendar.timeZone = moscowTimeZone
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = moscowTimeZone
        return formatter.string(from: date)
    }
}

extension DateUtils {
    static func getDateRangeForPeriod(_ period: String) -> (from: String, to: String) {
        switch period {
        case "today":
            let dateString = getCurrentDateString(daysAgo: 0)
            return (dateString, dateString)
        case "yesterday":
            let dateString = getCurrentDateString(daysAgo: 1)
            return (dateString, dateString)
        case "week":
            return (getCurrentDateString(daysAgo: 7), getCurrentDateString(daysAgo: 0))
        case "month":
            return (getCurrentDateString(daysAgo: 30), getCurrentDateString(daysAgo: 0))
        default:
            return (getCurrentDateString(daysAgo: 7), getCurrentDateString(daysAgo: 0))
        }
    }

    static func formatDate(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = moscowTimeZone
        return formatter.string(from: timestamp)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return "\(minutes) min \(remainingSeconds) sec"
        } else {
            return "\(seconds) sec"
        }
    }

    static func calculateQualityStars(_ quality: Int?) -> Int? {
        guard let quality = quality else { return nil }
        return min(5, max(1, (quality + 1) / 2))
    }
}
