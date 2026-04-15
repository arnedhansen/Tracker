import Foundation

@MainActor
final class TrackerStore: ObservableObject {
    @Published private(set) var entries: [DailyEntry] = []
    @Published var selectedDate: Date

    private let baseDirectory: String
    private let dateFormatter: DateFormatter
    private let csvPath: String

    init(baseDirectory: String) {
        self.baseDirectory = baseDirectory
        self.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        self.csvPath = "\(baseDirectory)/tracker_data.csv"
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        load()
    }

    var scoredEntries: [ScoredEntry] {
        ScoringEngine.scoredSeries(entries)
    }

    var missingDates: [Date] {
        guard let earliest = entries.map(\.date).min() else { return [selectedDate] }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        var date = calendar.startOfDay(for: earliest)
        var missing: [Date] = []
        let existing = Set(entries.map { calendar.startOfDay(for: $0.date) })
        while date <= end {
            if !existing.contains(date) {
                missing.append(date)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return missing
    }

    func entry(for date: Date) -> DailyEntry {
        let target = Calendar.current.startOfDay(for: date)
        var entry: DailyEntry
        if let existing = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: target) }) {
            entry = existing
        } else {
            entry = DailyEntry(date: target)
        }
        if ScoringEngine.isLegacySubjectiveSyncDate(entry.date) {
            entry.subjectiveRating = ScoringEngine.subjectiveRatingSyncedToOverall(for: entry)
        }
        return entry
    }

    func save(entry: DailyEntry) {
        var entry = entry
        syncLegacySubjectiveIfNeeded(&entry)
        if let idx = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date < $1.date }
        persist()
    }

    func updateMetric(date: Date, metric: TrackerMetric, value: Double) {
        let clamped = min(max(value, 0), 10)
        let target = Calendar.current.startOfDay(for: date)
        var entry = self.entry(for: target)
        entry.setValue(clamped, for: metric)
        save(entry: entry)
    }

    func ensureEntry(for date: Date) {
        let target = Calendar.current.startOfDay(for: date)
        if !entries.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: target) }) {
            save(entry: DailyEntry(date: target))
        }
    }

    private func load() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: csvPath) {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            entries = [DailyEntry(date: Calendar.current.startOfDay(for: yesterday))]
            persist()
            return
        }

        guard let content = try? String(contentsOfFile: csvPath, encoding: .utf8) else { return }
        let lines = content.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return }
        let header = splitCSVLine(lines[0])
        let indexByColumn = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })

        var loadedByDay: [Date: DailyEntry] = [:]
        for line in lines.dropFirst() {
            let f = splitCSVLine(line)
            guard let dateText = value("date", from: f, indexByColumn: indexByColumn),
                  let date = dateFormatter.date(from: dateText) else { continue }
            var e = DailyEntry(date: date)
            e.subjectiveRating = d(value("subjectiveRating", from: f, indexByColumn: indexByColumn))
            e.generalMood = d(value("generalMood", from: f, indexByColumn: indexByColumn))
            e.energy = d(value("energy", from: f, indexByColumn: indexByColumn))
            e.stress = d(value("stress", from: f, indexByColumn: indexByColumn))
            e.confidence = d(value("confidence", from: f, indexByColumn: indexByColumn))
            e.bodyImage = d(value("bodyImage", from: f, indexByColumn: indexByColumn))
            e.phdEnthusiasm = d(value("phdEnthusiasm", from: f, indexByColumn: indexByColumn))
            e.work = d(value("work", from: f, indexByColumn: indexByColumn))
            e.chores = d(value("chores", from: f, indexByColumn: indexByColumn))
            e.relaxation = d(value("relaxation", from: f, indexByColumn: indexByColumn))
            e.exercise = d(value("exercise", from: f, indexByColumn: indexByColumn))
            e.walkingCycling = d(value("walkingCycling", from: f, indexByColumn: indexByColumn))
            e.generalHealth = d(value("generalHealth", from: f, indexByColumn: indexByColumn))
            e.sleep = d(value("sleep", from: f, indexByColumn: indexByColumn))
            e.nutrition = d(value("nutrition", from: f, indexByColumn: indexByColumn))
            e.hydration = d(value("hydration", from: f, indexByColumn: indexByColumn))
            e.alcoholDrugs = d(value("alcoholDrugs", from: f, indexByColumn: indexByColumn))
            e.socialQuantity = d(value("socialQuantity", from: f, indexByColumn: indexByColumn))
            e.socialQuality = d(value("socialQuality", from: f, indexByColumn: indexByColumn))
            let day = Calendar.current.startOfDay(for: e.date)
            loadedByDay[day] = e
        }
        entries = loadedByDay.values.sorted { $0.date < $1.date }
        var changed = false
        for i in entries.indices where ScoringEngine.isLegacySubjectiveSyncDate(entries[i].date) {
            let synced = ScoringEngine.subjectiveRatingSyncedToOverall(for: entries[i])
            if abs(entries[i].subjectiveRating - synced) > 0.000_001 {
                entries[i].subjectiveRating = synced
                changed = true
            }
        }
        if changed { persist() }
    }

    private func persist() {
        let header = [
            "date", "subjectiveRating", "generalMood", "energy", "stress", "confidence", "bodyImage",
            "phdEnthusiasm", "work", "chores", "relaxation", "exercise", "walkingCycling", "generalHealth",
            "sleep", "nutrition", "hydration", "alcoholDrugs", "socialQuantity", "socialQuality"
        ].joined(separator: ",")

        let rows = entries.map { e in
            [
                dateFormatter.string(from: e.date), s(e.subjectiveRating), s(e.generalMood), s(e.energy),
                s(e.stress), s(e.confidence), s(e.bodyImage), s(e.phdEnthusiasm), s(e.work), s(e.chores), s(e.relaxation),
                s(e.exercise), s(e.walkingCycling), s(e.generalHealth), s(e.sleep), s(e.nutrition), s(e.hydration),
                s(e.alcoholDrugs), s(e.socialQuantity), s(e.socialQuality)
            ].joined(separator: ",")
        }
        let csv = ([header] + rows).joined(separator: "\n")
        try? csv.write(toFile: csvPath, atomically: true, encoding: .utf8)
    }

    private func syncLegacySubjectiveIfNeeded(_ entry: inout DailyEntry) {
        guard ScoringEngine.isLegacySubjectiveSyncDate(entry.date) else { return }
        entry.subjectiveRating = ScoringEngine.subjectiveRatingSyncedToOverall(for: entry)
    }

    private func d(_ value: String?) -> Double { Double(value ?? "") ?? 5.0 }
    private func s(_ value: Double) -> String { String(format: "%.2f", value) }
    private func value(_ column: String, from fields: [String], indexByColumn: [String: Int]) -> String? {
        guard let idx = indexByColumn[column], idx < fields.count else { return nil }
        return fields[idx]
    }

    private func splitCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        values.append(current)
        return values.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }
}
