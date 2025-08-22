import Foundation

enum DeviationState: Equatable {
    case within
    case overweight
    case underweight
}

struct DeviationMetrics {
    let delta: Double
    let state: DeviationState

    func displayString() -> String {
        String(format: "%+.1f%%", delta)
    }
}

struct DeviationAnalytics {
    static func deviation(actual: Double, target: Double, tolerance: Double) -> DeviationMetrics {
        let delta = actual - target
        let state: DeviationState
        if delta > tolerance {
            state = .overweight
        } else if delta < -tolerance {
            state = .underweight
        } else {
            state = .within
        }
        return DeviationMetrics(delta: delta, state: state)
    }

    static func shouldInclude(actual: Double, research: Double, user: Double, excluded: Bool, tolerance: Double, showResearch: Bool, showUser: Bool, onlyOut: Bool) -> Bool {
        if excluded { return !onlyOut }
        if !onlyOut { return true }
        var flagged = false
        if showResearch {
            if deviation(actual: actual, target: research, tolerance: tolerance).state != .within {
                flagged = true
            }
        }
        if showUser {
            if deviation(actual: actual, target: user, tolerance: tolerance).state != .within {
                flagged = true
            }
        }
        return flagged
    }
}
