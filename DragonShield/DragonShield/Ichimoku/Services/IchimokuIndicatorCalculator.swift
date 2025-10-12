import Foundation

final class IchimokuIndicatorCalculator {
    private let regressionWindow: Int

    init(regressionWindow: Int) {
        self.regressionWindow = regressionWindow
    }

    func computeIndicators(for bars: [IchimokuPriceBar]) -> [IchimokuIndicatorRow] {
        guard !bars.isEmpty else { return [] }
        let sortedBars = bars.sorted { $0.date < $1.date }
        let count = sortedBars.count
        var tenkanValues = Array<Double?>(repeating: nil, count: count)
        var kijunValues = Array<Double?>(repeating: nil, count: count)
        var senkouAForward = [Int: Double]()
        var senkouBForward = [Int: Double]()
        var chikouValues = Array<Double?>(repeating: nil, count: count)

        for i in 0..<count {
            if i >= 8 {
                let window = sortedBars[(i - 8)...i]
                let high = window.map { $0.high }.max() ?? 0
                let low = window.map { $0.low }.min() ?? 0
                tenkanValues[i] = (high + low) / 2.0
            }
            if i >= 25 {
                let window = sortedBars[(i - 25)...i]
                let high = window.map { $0.high }.max() ?? 0
                let low = window.map { $0.low }.min() ?? 0
                kijunValues[i] = (high + low) / 2.0
            }
            if let tenkan = tenkanValues[i], let kijun = kijunValues[i] {
                let forwardIndex = i + 26
                if forwardIndex < count {
                    senkouAForward[forwardIndex] = (tenkan + kijun) / 2.0
                }
            }
            if i >= 51 {
                let window = sortedBars[(i - 51)...i]
                let high = window.map { $0.high }.max() ?? 0
                let low = window.map { $0.low }.min() ?? 0
                let value = (high + low) / 2.0
                let forwardIndex = i + 26
                if forwardIndex < count {
                    senkouBForward[forwardIndex] = value
                }
            }
            let lagIndex = i - 26
            if lagIndex >= 0 {
                chikouValues[lagIndex] = sortedBars[i].close
            }
        }

        var tenkanSlopeValues = Array<Double?>(repeating: nil, count: count)
        var kijunSlopeValues = Array<Double?>(repeating: nil, count: count)
        if regressionWindow >= 2 {
            for i in 0..<count {
                if let slope = regressionSlope(values: tenkanValues, endIndex: i, window: regressionWindow) {
                    tenkanSlopeValues[i] = slope
                }
                if let slope = regressionSlope(values: kijunValues, endIndex: i, window: regressionWindow) {
                    kijunSlopeValues[i] = slope
                }
            }
        }

        var indicators: [IchimokuIndicatorRow] = []
        indicators.reserveCapacity(count)
        for i in 0..<count {
            let bar = sortedBars[i]
            let senkouA = senkouAForward[i]
            let senkouB = senkouBForward[i]
            let kijun = kijunValues[i]
            let close = bar.close
            let priceToKijun = (kijun != nil && kijun != 0) ? close / kijun! : nil
            let tenkan = tenkanValues[i]
            let tenkanKijunDistance: Double?
            if let tenkan, let kijun {
                tenkanKijunDistance = tenkan - kijun
            } else {
                tenkanKijunDistance = nil
            }
            indicators.append(IchimokuIndicatorRow(
                tickerId: bar.tickerId,
                date: bar.date,
                tenkan: tenkan,
                kijun: kijun,
                senkouA: senkouA,
                senkouB: senkouB,
                chikou: chikouValues[i],
                tenkanSlope: tenkanSlopeValues[i],
                kijunSlope: kijunSlopeValues[i],
                priceToKijunRatio: priceToKijun,
                tenkanKijunDistance: tenkanKijunDistance,
                momentumScore: nil
            ))
        }
        return indicators
    }

    private func regressionSlope(values: [Double?], endIndex: Int, window: Int) -> Double? {
        guard window >= 2, endIndex >= window - 1 else { return nil }
        var y: [Double] = []
        for i in stride(from: endIndex - window + 1, through: endIndex, by: 1) {
            if let value = values[i] {
                y.append(value)
            } else {
                return nil
            }
        }
        let n = Double(y.count)
        guard n >= 2 else { return nil }
        let xs = (0..<y.count).map { Double($0) }
        let sumX = xs.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)
        let sumXY = zip(xs, y).map { $0 * $1 }.reduce(0, +)
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }
}
