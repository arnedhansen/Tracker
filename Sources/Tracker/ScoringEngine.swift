import Foundation

enum ScoringEngine {
    static func overallScore(for entry: DailyEntry) -> Double {
        let emotional = average([
            entry.generalMood, entry.energy, entry.stress, entry.confidence, entry.bodyImage, entry.phdEnthusiasm
        ])
        let productivity = average([entry.work, entry.chores])
        let relaxSport = average([entry.relaxation, entry.exercise, entry.walkingCycling])
        let health = average([entry.generalHealth, entry.sleep, entry.nutrition, entry.hydration, entry.alcoholDrugs])
        let social = average([entry.socialQuantity, entry.socialQuality])
        let workLifeBalance = wlb(productivity: productivity, relaxSport: relaxSport)

        // Subjective rating is promoted to a core, equal domain.
        let total = emotional + productivity + relaxSport + health + social + workLifeBalance + entry.subjectiveRating
        return total / 7.0
    }

    static func wlb(productivity: Double, relaxSport: Double) -> Double {
        0.7 * max(productivity, relaxSport) + 0.3 * (10.0 - abs(productivity - relaxSport))
    }

    static func scoredSeries(_ entries: [DailyEntry]) -> [ScoredEntry] {
        let sorted = entries.sorted { $0.date < $1.date }
        let values = sorted.map { overallScore(for: $0) }
        let trend = rollingAverage(values: values, windowSize: 7)
        return sorted.enumerated().map { idx, entry in
            ScoredEntry(
                id: entry.date,
                date: entry.date,
                overallScore: values[idx],
                trendValue: trend[idx]
            )
        }
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func rollingAverage(values: [Double], windowSize: Int) -> [Double] {
        guard windowSize > 1 else { return values }
        var output: [Double] = []
        output.reserveCapacity(values.count)
        for idx in values.indices {
            let start = max(0, idx - (windowSize - 1))
            let window = values[start...idx]
            output.append(window.reduce(0, +) / Double(window.count))
        }
        return output
    }
}
