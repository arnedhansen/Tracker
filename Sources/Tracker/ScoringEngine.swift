import Foundation

enum ScoringEngine {
    struct DomainWeights {
        let emotional: Double
        let productivity: Double
        let recovery: Double
        let health: Double
        let social: Double
        let subjective: Double

        static let `default` = DomainWeights(
            emotional: 0.25,
            productivity: 0.15,
            recovery: 0.15,
            health: 0.20,
            social: 0.15,
            subjective: 0.10
        )
    }

    struct ScoreComparisonSummary {
        let meanLegacy: Double
        let meanCurrent: Double
        let meanDelta: Double
        let maxAbsoluteDelta: Double
    }

    /// Legacy implicit metric influence under the old `overallScore` formula.
    /// Values sum to ~1.0 and are kept to document old behavior and enable side-by-side comparisons.
    static let legacyMetricInfluenceByMetric: [TrackerMetric: Double] = [
        .generalMood: 1.0 / 42.0,
        .energy: 1.0 / 42.0,
        .stress: 1.0 / 42.0,
        .confidence: 1.0 / 42.0,
        .bodyImage: 1.0 / 42.0,
        .phdEnthusiasm: 1.0 / 42.0,
        .work: 2.0 / 21.0,
        .chores: 2.0 / 21.0,
        .relaxation: 5.0 / 126.0,
        .exercise: 5.0 / 126.0,
        .walkingCycling: 5.0 / 126.0,
        .generalHealth: 13.0 / 630.0,
        .sleep: 13.0 / 630.0,
        .nutrition: 13.0 / 630.0,
        .hydration: 13.0 / 630.0,
        .alcoholDrugs: 13.0 / 630.0,
        .socialQuantity: 2.0 / 21.0,
        .socialQuality: 2.0 / 21.0,
        .subjectiveRating: 1.0 / 7.0
    ]

    private static let domainWeights = DomainWeights.default

    /// Explicit metric weights to avoid hidden within-domain influence.
    /// "Stress" and "Alcohol & Drugs" are intentionally positively coded in this app:
    /// higher values represent better outcomes.
    private static let productivityMetricWeights: [TrackerMetric: Double] = [
        .work: 0.75,
        .chores: 0.25
    ]
    private static let recoveryMetricWeights: [TrackerMetric: Double] = [
        .relaxation: 0.40,
        .exercise: 0.35,
        .walkingCycling: 0.25
    ]
    private static let healthMetricWeights: [TrackerMetric: Double] = [
        .generalHealth: 0.25,
        .sleep: 0.30,
        .nutrition: 0.20,
        .hydration: 0.10,
        .alcoholDrugs: 0.15
    ]
    private static let socialMetricWeights: [TrackerMetric: Double] = [
        .socialQuality: 0.70,
        .socialQuantity: 0.30
    ]

    private struct DomainScores {
        let emotional: Double
        let productivity: Double
        let recovery: Double
        let health: Double
        let social: Double
    }

    /// Days strictly before 8 April 2026: subjective rating is derived so it equals overall (see `subjectiveRatingSyncedToOverall`).
    static func isLegacySubjectiveSyncDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8)) else { return false }
        return day < calendar.startOfDay(for: cutoff)
    }

    /// Weighted score contribution from all non-subjective domains before adding subjective and balance modifier.
    static func weightedCoreWithoutSubjective(for entry: DailyEntry) -> Double {
        let d = domainScores(for: entry)
        return (domainWeights.emotional * d.emotional) +
            (domainWeights.productivity * d.productivity) +
            (domainWeights.recovery * d.recovery) +
            (domainWeights.health * d.health) +
            (domainWeights.social * d.social)
    }

    /// Value for `subjectiveRating` such that it equals `overallScore` under the current weighted model:
    /// overall = core + ws * S + balance ; set S = overall => S = (core + balance) / (1 - ws).
    static func subjectiveRatingSyncedToOverall(for entry: DailyEntry) -> Double {
        let core = weightedCoreWithoutSubjective(for: entry)
        let d = domainScores(for: entry)
        let modifier = workLifeBalanceModifier(productivity: d.productivity, recovery: d.recovery)
        let denominator = max(0.000_001, 1.0 - domainWeights.subjective)
        return clamp((core + modifier) / denominator, min: 0, max: 10)
    }

    static func overallScore(for entry: DailyEntry) -> Double {
        let core = weightedCoreWithoutSubjective(for: entry)
        let d = domainScores(for: entry)
        let subjectiveContribution = domainWeights.subjective * entry.subjectiveRating
        let balanceModifier = workLifeBalanceModifier(productivity: d.productivity, recovery: d.recovery)
        return clamp(core + subjectiveContribution + balanceModifier, min: 0, max: 10)
    }

    static func legacyOverallScore(for entry: DailyEntry) -> Double {
        let emotional = average([
            entry.generalMood, entry.energy, entry.stress, entry.confidence, entry.bodyImage, entry.phdEnthusiasm
        ])
        let productivity = average([entry.work, entry.chores])
        let relaxSport = average([entry.relaxation, entry.exercise, entry.walkingCycling])
        let health = average([entry.generalHealth, entry.sleep, entry.nutrition, entry.hydration, entry.alcoholDrugs])
        let social = average([entry.socialQuantity, entry.socialQuality])
        let workLifeBalance = legacyWlb(productivity: productivity, relaxSport: relaxSport)
        let total = emotional + productivity + relaxSport + health + social + workLifeBalance + entry.subjectiveRating
        return total / 7.0
    }

    static func scoredSeries(_ entries: [DailyEntry]) -> [ScoredEntry] {
        let sorted = entries.sorted { $0.date < $1.date }
        let values = sorted.map { overallScore(for: $0) }
        let legacyValues = sorted.map { legacyOverallScore(for: $0) }
        let trend = rollingAverage(values: values, dayRadius: 3)
        let legacyTrend = rollingAverage(values: legacyValues, dayRadius: 3)
        return sorted.enumerated().map { idx, entry in
            ScoredEntry(
                id: entry.date,
                date: entry.date,
                overallScore: values[idx],
                trendValue: trend[idx],
                legacyOverallScore: legacyValues[idx],
                legacyTrendValue: legacyTrend[idx],
                isLegacySubjectiveDerived: isLegacySubjectiveSyncDate(entry.date)
            )
        }
    }

    static func compareLegacyVsCurrent(_ entries: [DailyEntry]) -> ScoreComparisonSummary {
        guard !entries.isEmpty else {
            return ScoreComparisonSummary(meanLegacy: 0, meanCurrent: 0, meanDelta: 0, maxAbsoluteDelta: 0)
        }
        let legacy = entries.map { legacyOverallScore(for: $0) }
        let current = entries.map { overallScore(for: $0) }
        let deltas = zip(current, legacy).map(-)
        return ScoreComparisonSummary(
            meanLegacy: average(legacy),
            meanCurrent: average(current),
            meanDelta: average(deltas),
            maxAbsoluteDelta: deltas.map { abs($0) }.max() ?? 0
        )
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func domainScores(for entry: DailyEntry) -> DomainScores {
        let emotional = average([
            entry.generalMood, entry.energy, entry.stress, entry.confidence, entry.bodyImage, entry.phdEnthusiasm
        ])
        let productivity = weightedAverage(
            [.work: entry.work, .chores: entry.chores],
            weights: productivityMetricWeights
        )
        let recovery = weightedAverage(
            [.relaxation: entry.relaxation, .exercise: entry.exercise, .walkingCycling: entry.walkingCycling],
            weights: recoveryMetricWeights
        )
        let health = weightedAverage(
            [
                .generalHealth: entry.generalHealth,
                .sleep: entry.sleep,
                .nutrition: entry.nutrition,
                .hydration: entry.hydration,
                .alcoholDrugs: entry.alcoholDrugs
            ],
            weights: healthMetricWeights
        )
        let social = weightedAverage(
            [.socialQuality: entry.socialQuality, .socialQuantity: entry.socialQuantity],
            weights: socialMetricWeights
        )
        return DomainScores(
            emotional: emotional,
            productivity: productivity,
            recovery: recovery,
            health: health,
            social: social
        )
    }

    private static func weightedAverage(_ values: [TrackerMetric: Double], weights: [TrackerMetric: Double]) -> Double {
        let numerator = values.reduce(0.0) { partial, item in
            partial + item.value * (weights[item.key] ?? 0)
        }
        let denominator = weights.values.reduce(0, +)
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    private static func workLifeBalanceModifier(productivity: Double, recovery: Double) -> Double {
        let normalizedMean = clamp((productivity + recovery) / 20.0, min: 0, max: 1)
        let normalizedBalance = clamp(1.0 - abs(productivity - recovery) / 10.0, min: 0, max: 1)
        let quality = normalizedMean * normalizedBalance
        return (quality - 0.5) * 1.0 // [-0.5, +0.5]
    }

    private static func legacyWlb(productivity: Double, relaxSport: Double) -> Double {
        let mean = (productivity + relaxSport) / 2.0
        let imbalancePenalty = abs(productivity - relaxSport) / 2.0
        return min(max(mean - imbalancePenalty, 1.0), 10.0)
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(Swift.max(value, lower), upper)
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
