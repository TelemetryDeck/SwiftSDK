import Foundation

enum TimezoneFormatting {
    static func utcOffsetString(from timeZone: TimeZone = .current) -> String {
        let secondsFromGMT = timeZone.secondsFromGMT()
        let hours = abs(secondsFromGMT) / 3600
        let minutes = abs(secondsFromGMT) / 60 % 60
        let sign = secondsFromGMT >= 0 ? "+" : "-"
        if minutes > 0 {
            return "UTC\(sign)\(hours):\(String(format: "%02d", minutes))"
        }
        return "UTC\(sign)\(hours)"
    }
}
