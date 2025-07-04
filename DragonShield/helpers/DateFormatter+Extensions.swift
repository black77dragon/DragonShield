// DragonShield/Utils/DateFormatter+Extensions.swift
// MARK: - Version 1.1 (2025-06-15)
// MARK: - History
// - 1.0 -> 1.1: Added iso8601DateTime formatter for full timestamp parsing.
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

    static let iso8601DateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Parses dates in the Swiss `dd.MM.yyyy` format.
    static let swissDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_CH")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
