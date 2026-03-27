import Foundation

extension TimeInterval {
    /// Formats a time interval as a human-readable relative string.
    /// e.g. "3 min ago", "1h 23m", "Just now"
    var relativeDisplay: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if totalSeconds < 60 {
            return "Just now"
        } else if hours == 0 {
            return "\(minutes) min ago"
        } else {
            return "\(hours)h \(minutes)m ago"
        }
    }

    /// Formats as a live counter display: "HH:MM:SS" or "MM:SS"
    var counterDisplay: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formats as a concise duration: "2.3s", "45s", "1m 30s"
    var durationDisplay: String {
        if self < 10 {
            return String(format: "%.1fs", self)
        } else if self < 60 {
            return "\(Int(self))s"
        } else {
            let minutes = Int(self) / 60
            let seconds = Int(self) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

extension Date {
    /// Short time string: "2:34 PM"
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    /// Section header format: "Today", "Yesterday", or "Mar 25"
    var sectionHeaderString: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}
