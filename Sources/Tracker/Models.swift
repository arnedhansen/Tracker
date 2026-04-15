import Foundation

struct DailyEntry: Identifiable, Hashable {
    let date: Date
    var subjectiveRating: Double
    var generalMood: Double
    var energy: Double
    var stress: Double
    var confidence: Double
    var bodyImage: Double
    var phdEnthusiasm: Double
    var work: Double
    var chores: Double
    var relaxation: Double
    var exercise: Double
    var walkingCycling: Double
    var generalHealth: Double
    var sleep: Double
    var nutrition: Double
    var hydration: Double
    var alcoholDrugs: Double
    var socialQuantity: Double
    var socialQuality: Double
    
    var id: Date { date }

    init(date: Date) {
        self.date = date
        self.subjectiveRating = 5
        self.generalMood = 5
        self.energy = 5
        self.stress = 5
        self.confidence = 5
        self.bodyImage = 5
        self.phdEnthusiasm = 5
        self.work = 5
        self.chores = 5
        self.relaxation = 5
        self.exercise = 5
        self.walkingCycling = 5
        self.generalHealth = 5
        self.sleep = 5
        self.nutrition = 5
        self.hydration = 5
        self.alcoholDrugs = 5
        self.socialQuantity = 5
        self.socialQuality = 5
    }
}

extension DailyEntry {
    func value(for metric: TrackerMetric) -> Double {
        switch metric {
        case .subjectiveRating: return subjectiveRating
        case .generalMood: return generalMood
        case .energy: return energy
        case .stress: return stress
        case .confidence: return confidence
        case .bodyImage: return bodyImage
        case .phdEnthusiasm: return phdEnthusiasm
        case .work: return work
        case .chores: return chores
        case .relaxation: return relaxation
        case .exercise: return exercise
        case .walkingCycling: return walkingCycling
        case .generalHealth: return generalHealth
        case .sleep: return sleep
        case .nutrition: return nutrition
        case .hydration: return hydration
        case .alcoholDrugs: return alcoholDrugs
        case .socialQuantity: return socialQuantity
        case .socialQuality: return socialQuality
        }
    }

    mutating func setValue(_ value: Double, for metric: TrackerMetric) {
        switch metric {
        case .subjectiveRating: subjectiveRating = value
        case .generalMood: generalMood = value
        case .energy: energy = value
        case .stress: stress = value
        case .confidence: confidence = value
        case .bodyImage: bodyImage = value
        case .phdEnthusiasm: phdEnthusiasm = value
        case .work: work = value
        case .chores: chores = value
        case .relaxation: relaxation = value
        case .exercise: exercise = value
        case .walkingCycling: walkingCycling = value
        case .generalHealth: generalHealth = value
        case .sleep: sleep = value
        case .nutrition: nutrition = value
        case .hydration: hydration = value
        case .alcoholDrugs: alcoholDrugs = value
        case .socialQuantity: socialQuantity = value
        case .socialQuality: socialQuality = value
        }
    }
}

struct ScoredEntry: Identifiable {
    let id: Date
    let date: Date
    let overallScore: Double
    let trendValue: Double
    let legacyOverallScore: Double
    let legacyTrendValue: Double
    let isLegacySubjectiveDerived: Bool
}

enum TrackerMetric: String, CaseIterable {
    case subjectiveRating = "Subjective Day Rating"
    case generalMood = "General Mood"
    case energy = "Energy"
    case stress = "Stress"
    case confidence = "Confidence"
    case bodyImage = "Body Image"
    case phdEnthusiasm = "PhD Enthusiasm"
    case work = "Work"
    case chores = "Chores"
    case relaxation = "Relaxation"
    case exercise = "Exercise"
    case walkingCycling = "Walking / Cycling"
    case generalHealth = "General Health"
    case sleep = "Sleep"
    case nutrition = "Nutrition"
    case hydration = "Hydration"
    case alcoholDrugs = "Alcohol & Drugs"
    case socialQuantity = "Social Quantity"
    case socialQuality = "Social Quality"
}
