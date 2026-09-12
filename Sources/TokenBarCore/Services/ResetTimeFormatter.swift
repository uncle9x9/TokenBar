import Foundation

public enum ResetTimeFormatter {
    /// Formats a reset date into a complete, prominent reset string:
    /// - Near-term (< 24h): "Resets in 31 min", "Resets in 2 hr 14 min"
    /// - Tomorrow (< 48h): "Resets Tomorrow 6:00 PM"
    /// - Longer (< 7d): "Resets Fri 9:00 AM"
    /// - Further: "Resets Sep 18, 9:00 AM"
    public static func resetLine(date: Date?, asAbsolute: Bool = false, now: Date = Date()) -> String? {
        guard let date else { return nil }
        return "Resets \(format(date: date, asAbsolute: asAbsolute, now: now))"
    }

    public static func format(date: Date, asAbsolute: Bool = false, now: Date = Date()) -> String {
        if asAbsolute {
            return absoluteDescription(from: date, now: now)
        }
        return smartClaudeCodeFormat(date: date, now: now)
    }

    public static func smartClaudeCodeFormat(date: Date, now: Date = Date()) -> String {
        let diff = date.timeIntervalSince(now)
        if diff <= 0 {
            return "now"
        }

        let calendar = Calendar.current

        // Near-term (< 24 hours): relative duration
        if diff < 24 * 3600 {
            let totalMinutes = max(1, Int(ceil(diff / 60.0)))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return minutes > 0 ? "in \(hours) hr \(minutes) min" : "in \(hours) hr"
            } else {
                return "in \(minutes) min"
            }
        }

        // Longer / fixed reset: exact time
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }

        // Within 7 days: day of week + time (e.g. "Fri 9:00 AM")
        if let weekLater = calendar.date(byAdding: .day, value: 7, to: now), date < weekLater {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEE h:mm a"
            return weekdayFormatter.string(from: date)
        }

        // Beyond 7 days: "Sep 18, 9:00 AM"
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "MMM d, h:mm a"
        return fullFormatter.string(from: date)
    }

    public static func countdownDescription(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        if seconds < 1 { return "now" }
        let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(totalMinutes)m"
    }

    public static func absoluteDescription(from date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        if calendar.isDate(date, inSameDayAs: now) {
            return "Today, \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow, \(timeFormatter.string(from: date))"
        }

        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "EEE h:mm a"
        return fullFormatter.string(from: date)
    }

    public static func relativeUpdatedDescription(from date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        if elapsed < 5 {
            return "Just now"
        }
        if elapsed < 60 {
            return "\(elapsed)s ago"
        }
        let minutes = elapsed / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = hours / 24
        return "\(days)d ago"
    }
}
