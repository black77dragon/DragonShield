// DragonShield/Models/ThemeStatusSaveError.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Represents errors when saving Theme Status.

import Foundation

enum ThemeStatusSaveError: Error, Equatable {
    case codeInvalid
    case codeExists
    case nameExists
    case couldNotSetDefault
    case unknown
}
