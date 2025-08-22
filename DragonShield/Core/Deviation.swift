// DragonShield/Core/Deviation.swift
// Utility for deviation calculations and tolerance classification.

import Foundation

enum DeviationState {
    case within
    case overweight
    case underweight
}

enum Deviation {
    static func state(for delta: Double, tolerance: Double) -> DeviationState {
        if delta > tolerance { return .overweight }
        if delta < -tolerance { return .underweight }
        return .within
    }

    static func isOutOfTolerance(delta: Double?, tolerance: Double) -> Bool {
        guard let d = delta else { return false }
        return abs(d) > tolerance
    }
}
