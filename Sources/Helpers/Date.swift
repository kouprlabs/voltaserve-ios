import Foundation

extension String {
    func relativeDate() -> String {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: self) else {
            return ""
        }

        let now = Date()
        let calendar = Calendar.current
        let hoursDiff = abs(now.timeIntervalSince(date)) / 3600

        if calendar.isDateInToday(date) {
            if hoursDiff <= 12 {
                return timeAgo(from: date, to: now)
            } else {
                return "Today"
            }
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return formattedDate(date, format: "d MMM")
        } else {
            return formattedDate(date, format: "d MMM yyyy")
        }
    }
}

func timeAgo(from startDate: Date, to endDate: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: startDate, relativeTo: endDate)
}

func formattedDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

extension Int {
    func unixTimestampToISO8601() -> String {
        ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(self)))
    }

    func unixTimestampToDurationString() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = (self % 3600) % 60
        return "\(hours)h \(minutes)m \(seconds)s"
    }
}