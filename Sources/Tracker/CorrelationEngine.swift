import Foundation

enum CorrelationEngine {
    struct Pair: Identifiable {
        let left: TrackerMetric
        let right: TrackerMetric
        let correlation: Double
        let samples: Int

        var id: String { "\(left.rawValue)|\(right.rawValue)" }
    }

    struct OverallCorrelation: Identifiable {
        let metric: TrackerMetric
        let correlation: Double
        let samples: Int

        var id: String { metric.rawValue }
    }

    struct Summary {
        let metrics: [TrackerMetric]
        let matrix: [[Double?]]
        let strongestPairs: [Pair]
        let correlationWithOverall: [OverallCorrelation]
        let dayCount: Int
    }

    static func summary(
        entries: [DailyEntry],
        metrics: [TrackerMetric],
        strongestPairLimit: Int = 10
    ) -> Summary {
        let sorted = entries.sorted { $0.date < $1.date }
        let dayCount = sorted.count
        guard dayCount >= 2, !metrics.isEmpty else {
            return Summary(
                metrics: metrics,
                matrix: Array(repeating: Array(repeating: nil, count: metrics.count), count: metrics.count),
                strongestPairs: [],
                correlationWithOverall: [],
                dayCount: dayCount
            )
        }

        let valuesByMetric = Dictionary(uniqueKeysWithValues: metrics.map { metric in
            (metric, sorted.map { $0.value(for: metric) })
        })
        let overall = sorted.map { ScoringEngine.overallScore(for: $0) }

        var matrix = Array(
            repeating: Array(repeating: Optional<Double>.none, count: metrics.count),
            count: metrics.count
        )
        var strongestCandidates: [Pair] = []
        var overallCandidates: [OverallCorrelation] = []

        for rowIndex in metrics.indices {
            let rowMetric = metrics[rowIndex]
            guard let rowValues = valuesByMetric[rowMetric] else { continue }
            for columnIndex in metrics.indices {
                let columnMetric = metrics[columnIndex]
                guard let columnValues = valuesByMetric[columnMetric] else { continue }
                guard let r = pearson(rowValues, columnValues) else { continue }
                matrix[rowIndex][columnIndex] = r
                if columnIndex > rowIndex {
                    strongestCandidates.append(
                        Pair(left: rowMetric, right: columnMetric, correlation: r, samples: rowValues.count)
                    )
                }
            }

            if let rOverall = pearson(rowValues, overall) {
                overallCandidates.append(
                    OverallCorrelation(metric: rowMetric, correlation: rOverall, samples: rowValues.count)
                )
            }
        }

        let strongestPairs = strongestCandidates
            .sorted { abs($0.correlation) > abs($1.correlation) }
            .prefix(strongestPairLimit)
            .map { $0 }

        let correlationWithOverall = overallCandidates
            .sorted { $0.correlation > $1.correlation }

        return Summary(
            metrics: metrics,
            matrix: matrix,
            strongestPairs: strongestPairs,
            correlationWithOverall: correlationWithOverall,
            dayCount: dayCount
        )
    }

    private static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var numerator = 0.0
        var sumSqX = 0.0
        var sumSqY = 0.0
        for (xValue, yValue) in zip(x, y) {
            let dx = xValue - meanX
            let dy = yValue - meanY
            numerator += dx * dy
            sumSqX += dx * dx
            sumSqY += dy * dy
        }

        let denominator = sqrt(sumSqX * sumSqY)
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }
}
