// DragonShield/Utils/DateFormatter+Extensions.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: ISO8601 DateFormatter for consistent date handling.

import Foundation

extension DateFormatter {
    static let iso8601DateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Use POSIX locale for fixed-format dates to avoid issues with user's region settings
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Use a consistent calendar
        formatter.calendar = Calendar(identifier: .iso8601)
        // Set a consistent time zone, e.g., UTC, if dates are meant to be universal
        // For date-only, this primarily affects how the Date object is created from the string
        // if the string doesn't have time/timezone info.
        // If dates are local, ensure this matches how they are stored/interpreted.
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Or TimeZone.current if dates are local
        return formatter
    }()
}
