import Foundation

enum DeviationState {
    case within
    case over
    case under
}

func computeDelta(actual: Double, target: Double) -> Double {
    actual - target
}

func deviationState(delta: Double, tolerance: Double) -> DeviationState {
    if delta > tolerance {
        return .over
    } else if delta < -tolerance {
        return .under
    } else {
        return .within
    }
}

func rowOutOfTolerance(actual: Double, research: Double, user: Double, status: String, tolerance: Double, showResearch: Bool, showUser: Bool) -> Bool {
    if status == "FX missing — excluded" {
        return false
    }
    var flag = false
    if showResearch && abs(actual - research) > tolerance {
        flag = true
    }
    if showUser && abs(actual - user) > tolerance {
        flag = true
    }
    return flag
}

