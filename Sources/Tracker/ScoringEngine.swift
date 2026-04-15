import Foundation

enum ScoringEngine {
    /// Days strictly before 8 April 2026: subjective rating is derived so it equals overall (see `subjectiveRatingSyncedToOverall`).
    static func isLegacySubjectiveSyncDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8)) else { return false }
        return day < calendar.startOfDay(for: cutoff)
    }

    /// Sum of the six scored domains excluding subjective (same construction as `overallScore`).
    static func sumOfSixDomains(for entry: DailyEntry) -> Double {
        let emotional = average([
            entry.generalMood, entry.energy, entry.stress, entry.confidence, entry.bodyImage, entry.phdEnthusiasm
        ])
        let productivity = average([entry.work, entry.chores])
        let relaxSport = average([entry.relaxation, entry.exercise, entry.walkingCycling])
        let health = average([entry.generalHealth, entry.sleep, entry.nutrition, entry.hydration, entry.alcoholDrugs])
        let social = average([entry.socialQuantity, entry.socialQuality])
        let workLifeBalance = wlb(productivity: productivity, relaxSport: relaxSport)
        return emotional + productivity + relaxSport + health + social + workLifeBalance
    }

    /// Value for `subjectiveRating` such that it equals `overallScore` given the current other metrics: overall = (S + overall) / 7 ⇒ overall = S / 6.
    static func subjectiveRatingSyncedToOverall(for entry: DailyEntry) -> Double {
        let s = sumOfSixDomains(for: entry)
        return min(max(s / 6.0, 0), 10)
    }

    static func overallScore(for entry: DailyEntry) -> Double {
        let s = sumOfSixDomains(for: entry)
        // Subjective rating is promoted to a core, equal domain.
        let total = s + entry.subjectiveRating
        return total / 7.0
    }

    static func wlb(productivity: Double, relaxSport: Double) -> Double {
        let mean = (productivity + relaxSport) / 2.0
        let imbalancePenalty = abs(productivity - relaxSport) / 2.0
        return min(max(mean - imbalancePenalty, 1.0), 10.0)
    }

    static func scoredSeries(_ entries: [DailyEntry]) -> [ScoredEntry] {
        let sorted = entries.sorted { $0.date < $1.date }
        let values = sorted.map { overallScore(for: $0) }
        let trend = rollingAverage(values: values, dayRadius: 3)
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

    /// Centered mean over each day ± `dayRadius` neighbors (inclusive), i.e. ±3 days → up to 7 values.
    private static func rollingAverage(values: [Double], dayRadius: Int) -> [Double] {
        guard dayRadius > 0 else { return values }
        var output: [Double] = []
        output.reserveCapacity(values.count)
        for idx in values.indices {
            let start = max(0, idx - dayRadius)
            let end = min(values.count - 1, idx + dayRadius)
            let window = values[start...end]
            output.append(window.reduce(0, +) / Double(window.count))
        }
        return output
    }
}
