import SwiftUI
import Charts

private struct CellID: Hashable {
    let row: Int
    let column: Int
}

struct ContentView: View {
    @EnvironmentObject private var store: TrackerStore
    @FocusState private var focusedCell: CellID?
    @State private var didScrollTableToBottom = false

    private let tableMetrics: [TrackerMetric] = [
        .generalMood, .energy, .stress, .confidence, .bodyImage, .phdEnthusiasm, .work, .chores,
        .relaxation, .exercise, .walkingCycling, .generalHealth, .sleep, .nutrition, .hydration,
        .alcoholDrugs, .socialQuantity, .socialQuality, .subjectiveRating
    ]
    private let groupSpecs: [(title: String, metrics: [TrackerMetric])] = [
        ("Emotional & Motivational State", [.generalMood, .energy, .stress, .confidence, .bodyImage, .phdEnthusiasm]),
        ("Productivity", [.work, .chores]),
        ("Relaxation", [.relaxation, .exercise, .walkingCycling]),
        ("Physical Health", [.generalHealth, .sleep, .nutrition, .hydration, .alcoholDrugs]),
        ("Social", [.socialQuantity, .socialQuality]),
        ("Subjective", [.subjectiveRating])
    ]
    @State private var expandedGroups: Set<String> = []

    private let navy = Color(red: 0.13, green: 0.23, blue: 0.36)
    private let lime = Color(red: 0.78, green: 0.84, blue: 0.29)
    private let barBlue = Color(red: 0.29, green: 0.46, blue: 0.76)
    private let sheetBg = Color(red: 0.94, green: 0.95, blue: 0.97)

    var body: some View {
        GeometryReader { proxy in
            let horizontalPaddingLeading: CGFloat = 18
            let horizontalPaddingTrailing: CGFloat = 24
            let horizontalGap: CGFloat = 14
            let verticalPadding: CGFloat = 18
            let stackSpacing: CGFloat = 14
            let headerHeight: CGFloat = 34
            let availablePanelWidth = max(
                proxy.size.width - horizontalPaddingLeading - horizontalPaddingTrailing,
                700
            )
            let bottomRowUsableWidth = max(availablePanelWidth - horizontalGap, 300)
            let tablePanelWidth = bottomRowUsableWidth * 0.75
            let miniPanelWidth = bottomRowUsableWidth * 0.25
            let availableContentHeight = max(
                proxy.size.height - (verticalPadding * 2) - (stackSpacing * 2) - headerHeight,
                300
            )
            let topRowHeight = availableContentHeight * (2.0 / 3.0)
            let bottomRowHeight = max(availableContentHeight - topRowHeight, 120)

            VStack(spacing: stackSpacing) {
                header
                topChart
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: topRowHeight)
                HStack(spacing: horizontalGap) {
                    csvLikeEntryGrid(availableWidth: tablePanelWidth)
                        .frame(width: tablePanelWidth, alignment: .leading)
                        .frame(height: bottomRowHeight)
                    groupedChartsPanel
                        .frame(width: miniPanelWidth, height: bottomRowHeight)
                }
                .frame(width: availablePanelWidth, alignment: .leading)
            }
            .padding(.leading, horizontalPaddingLeading)
            .padding(.trailing, horizontalPaddingTrailing)
            .padding(.vertical, verticalPadding)
            .dynamicTypeSize(.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(sheetBg)
            .onAppear {
                store.ensureEntry(for: store.selectedDate)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(navy)
                Image(systemName: "waveform.path.ecg")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(lime)
            }
            .frame(width: 34, height: 34)
            Text("Arne Daily Tracker")
                .font(.title.weight(.bold))
                .foregroundStyle(navy)
            Spacer()
        }
    }

    private var topChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Overview Year")
            Chart {
                ForEach(store.scoredEntries) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Overall", point.overallScore),
                        width: .fixed(2.8)
                    )
                    .foregroundStyle(barBlue)
                    .zIndex(0)
                }
                ForEach(store.scoredEntries) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Trend", point.trendValue))
                        .lineStyle(StrokeStyle(lineWidth: 3.1))
                        .foregroundStyle(Color.orange)
                        .zIndex(2)
                }
            }
            .chartYScale(domain: 1...10)
            .chartXScale(domain: yearDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: Array(1...10)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(Color.gray.opacity(0.35))
                    AxisTick()
                    AxisValueLabel()
                        .foregroundStyle(navy)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .chartXAxis {
                AxisMarks(values: monthTickDates) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(navy)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.clipped()
            }
            .padding(14)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(navy.opacity(0.15), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                YearProgressDonut(
                    progress: yearProgress,
                    tintColor: lime
                )
                .padding(.top, 10)
                .padding(.trailing, 10)
                .allowsHitTesting(false)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(sheetBg))
    }

    private var groupedChartsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groupSpecs, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                if expandedGroups.contains(group.title) {
                                    expandedGroups.remove(group.title)
                                } else {
                                    expandedGroups.insert(group.title)
                                }
                            } label: {
                                HStack {
                                    Text(group.title)
                                        .font(.caption.weight(.bold).smallCaps())
                                        .foregroundStyle(lime)
                                    Spacer()
                                    Image(systemName: expandedGroups.contains(group.title) ? "chevron.down" : "chevron.right")
                                        .foregroundStyle(lime)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(navy)
                            }
                            .buttonStyle(.plain)

                            if expandedGroups.contains(group.title) {
                                ForEach(group.metrics, id: \.rawValue) { metric in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(metric.rawValue)
                                            .font(.caption2.weight(.bold).smallCaps())
                                            .foregroundStyle(navy)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(minHeight: 19)
                                            .background(lime)
                                            .overlay(Rectangle().stroke(navy.opacity(0.2), lineWidth: 0.5))
                                        Chart(store.scoredEntries) { point in
                                            BarMark(
                                                x: .value("Date", point.date),
                                                y: .value(metric.rawValue, valueForMetric(metric, on: point.id)),
                                                width: .fixed(3.2)
                                            )
                                            .foregroundStyle(barBlue)
                                        }
                                        .chartYScale(domain: 1...10)
                                        .chartXScale(domain: yearDomain)
                                        .chartYAxis {
                                            AxisMarks(position: .leading, values: Array(1...10)) { value in
                                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                                                    .foregroundStyle(Color.gray.opacity(0.33))
                                                AxisTick()
                                                AxisValueLabel()
                                                    .font(.system(size: 7.5))
                                                    .foregroundStyle(navy)
                                            }
                                        }
                                        .chartXAxis {
                                            AxisMarks(values: monthTickDates) { value in
                                                AxisTick()
                                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(navy)
                                            }
                                        }
                                        .frame(height: 74)
                                        .padding(.horizontal, 6)
                                        .background(Color.white)
                                        .overlay(Rectangle().stroke(navy.opacity(0.15), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(sheetBg))
    }

    private func csvLikeEntryGrid(availableWidth: CGFloat) -> some View {
        let missing = Set(store.missingDates.map { Calendar.current.startOfDay(for: $0) })
        let entriesByDate = store.entries.reduce(into: [Date: DailyEntry]()) { result, entry in
            result[Calendar.current.startOfDay(for: entry.date)] = entry
        }
        let dates = allDatesAscending()
        let dateColumnWidth: CGFloat = 106
        let overallWidth: CGFloat = 39
        let cellHeight: CGFloat = 38
        let minimumMetricWidth: CGFloat = 30
        let targetWidth = max(availableWidth, 700)
        let adaptiveMetricWidth = floor((targetWidth - dateColumnWidth - overallWidth) / CGFloat(tableMetrics.count))
        let metricCellWidth = max(minimumMetricWidth, adaptiveMetricWidth)
        let tableWidth = dateColumnWidth + (CGFloat(tableMetrics.count) * metricCellWidth) + overallWidth

        return VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { reader in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(Array(dates.enumerated()), id: \.element) { rowIndex, date in
                                tableRow(
                                    date: date,
                                    rowIndex: rowIndex,
                                    rowCount: dates.count,
                                    entry: entriesByDate[date] ?? DailyEntry(date: date),
                                    rowMissing: missing.contains(date),
                                    dateColumnWidth: dateColumnWidth,
                                    metricCellWidth: metricCellWidth,
                                    overallWidth: overallWidth,
                                    cellHeight: cellHeight
                                )
                                .id(date)
                                .frame(width: tableWidth, alignment: .leading)
                            }
                        } header: {
                            tablePinnedHeader(
                                dateColumnWidth: dateColumnWidth,
                                metricCellWidth: metricCellWidth,
                                overallWidth: overallWidth
                            )
                            .frame(width: tableWidth, alignment: .leading)
                        }
                    }
                    .frame(minWidth: tableWidth, maxWidth: .infinity, alignment: .leading)
                }
                .onAppear {
                    guard !didScrollTableToBottom, let lastDate = dates.last else { return }
                    didScrollTableToBottom = true
                    DispatchQueue.main.async {
                        reader.scrollTo(lastDate, anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(sheetBg))
    }

    private func moveFocus(row: Int, column: Int, direction: MoveDirection, rowCount: Int) {
        let maxColumn = tableMetrics.count - 1
        var targetRow = row
        var targetColumn = column
        switch direction {
        case .right:
            if targetColumn < maxColumn {
                targetColumn += 1
            } else if targetRow + 1 < rowCount {
                targetRow += 1
                targetColumn = 0
            }
        case .left:
            if targetColumn > 0 {
                targetColumn -= 1
            } else if targetRow > 0 {
                targetRow -= 1
                targetColumn = maxColumn
            }
        case .down:
            targetRow = min(rowCount - 1, row + 1)
        case .up:
            targetRow = max(0, row - 1)
        }
        focusedCell = CellID(row: targetRow, column: targetColumn)
    }

    private func tableHeaderCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.callout.weight(.bold))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: width, height: 30)
            .background(navy.opacity(0.9))
            .foregroundStyle(lime)
            .overlay(Rectangle().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
    }

    private func tablePinnedHeader(dateColumnWidth: CGFloat, metricCellWidth: CGFloat, overallWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            tableHeaderCell("Date", width: dateColumnWidth)
            ForEach(tableMetrics, id: \.rawValue) { metric in
                tableHeaderCell(shortLabel(metric.rawValue), width: metricCellWidth)
            }
            tableHeaderCell("Overall", width: overallWidth)
        }
    }

    private func tableRow(
        date: Date,
        rowIndex: Int,
        rowCount: Int,
        entry: DailyEntry,
        rowMissing: Bool,
        dateColumnWidth: CGFloat,
        metricCellWidth: CGFloat,
        overallWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            Text(shortDate(date))
                .font(.callout.monospacedDigit().weight(.bold))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.22))
                .frame(width: dateColumnWidth, height: cellHeight)
                .background(rowMissing ? Color.blue.opacity(0.08) : Color.white)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.2), lineWidth: 0.5))

            ForEach(Array(tableMetrics.enumerated()), id: \.offset) { colIndex, metric in
                NumericMetricCell(
                    value: entry.value(for: metric),
                    isFocused: focusedCell == CellID(row: rowIndex, column: colIndex),
                    onFocus: { focusedCell = CellID(row: rowIndex, column: colIndex) },
                    onCommit: { newValue in
                        store.updateMetric(date: date, metric: metric, value: newValue)
                    },
                    onNavigate: { moveFocus(row: rowIndex, column: colIndex, direction: $0, rowCount: rowCount) }
                )
                .focused($focusedCell, equals: CellID(row: rowIndex, column: colIndex))
                .frame(width: metricCellWidth, height: cellHeight)
            }

            Text(String(format: "%.2f", ScoringEngine.overallScore(for: entry)))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.22))
                .frame(width: overallWidth, height: cellHeight)
                .background(rowMissing ? Color.blue.opacity(0.08) : Color.white)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.2), lineWidth: 0.5))
        }
    }

    private func shortLabel(_ source: String) -> String {
        switch source {
        case "Subjective Day Rating": return "Subjective"
        case "General Mood": return "Mood"
        case "Body Image": return "Body"
        case "PhD Enthusiasm": return "PhD"
        case "Walking / Cycling": return "Walk/Cycle"
        case "General Health": return "Health"
        case "Alcohol & Drugs": return "A&D"
        case "Social Quantity": return "Soc Qty"
        case "Social Quality": return "Soc Qual"
        default: return source
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "EEE dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func valueForMetric(_ metric: TrackerMetric, on date: Date) -> Double {
        guard let entry = store.entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else { return 0 }
        return entry.value(for: metric)
    }

    private func allDatesAscending() -> [Date] {
        let calendar = Calendar.current
        let latest = calendar.startOfDay(for: Date().addingTimeInterval(-86400))
        let earliest = calendar.startOfDay(for: store.entries.map(\.date).min() ?? latest)
        var dates: [Date] = []
        var date = earliest
        while date <= latest {
            dates.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return dates
    }

    private var yearProgress: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let year = calendar.component(.year, from: today)
        let totalDays = (calendar.range(of: .day, in: .year, for: calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today)?.count) ?? 365
        return min(max(Double(dayOfYear) / Double(totalDays), 0), 1)
    }

    private var displayYear: Int {
        let calendar = Calendar.current
        let referenceDate = store.entries.map(\.date).max() ?? store.selectedDate
        return calendar.component(.year, from: referenceDate)
    }

    private var yearDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: displayYear, month: 1, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: displayYear + 1, month: 1, day: 1))?.addingTimeInterval(-1) ?? start
        return start...end
    }

    private var monthTickDates: [Date] {
        let calendar = Calendar.current
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: displayYear, month: month, day: 1))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold).smallCaps())
            .foregroundStyle(lime)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(navy)
    }
}

private enum MoveDirection {
    case right
    case left
    case down
    case up
}

private struct NumericMetricCell: View {
    @State private var text: String
    let value: Double
    let isFocused: Bool
    let onFocus: () -> Void
    let onCommit: (Double) -> Void
    let onNavigate: (MoveDirection) -> Void

    init(
        value: Double,
        isFocused: Bool,
        onFocus: @escaping () -> Void,
        onCommit: @escaping (Double) -> Void,
        onNavigate: @escaping (MoveDirection) -> Void
    ) {
        self.value = value
        self.isFocused = isFocused
        self.onFocus = onFocus
        self.onCommit = onCommit
        self.onNavigate = onNavigate
        _text = State(initialValue: String(format: "%.1f", value))
    }

    var body: some View {
        ZStack {
            heatColor(for: value)
            TextField("", text: $text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .textFieldStyle(.plain)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().stroke(isFocused ? Color.blue : Color.blue.opacity(0.2), lineWidth: isFocused ? 1.5 : 0.5))
        .onTapGesture {
            onFocus()
        }
        .onAppear { text = String(format: "%.0f", value.rounded()) }
        .onChange(of: value) { _, newValue in text = String(format: "%.0f", newValue.rounded()) }
        .onSubmit {
            commitValue()
            onNavigate(.right)
        }
        .onKeyPress(.tab) {
            commitValue()
            onNavigate(.right)
            return .handled
        }
        .onKeyPress(.upArrow) {
            commitValue()
            onNavigate(.up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            commitValue()
            onNavigate(.down)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            onNavigate(.left)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            onNavigate(.right)
            return .handled
        }
    }

    private func commitValue() {
        guard let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) else {
            text = String(format: "%.0f", value.rounded())
            return
        }
        let clamped = min(max(parsed, 1), 10).rounded()
        text = String(format: "%.0f", clamped)
        onCommit(clamped)
    }

    private func heatColor(for value: Double) -> Color {
        let t = min(max((value - 1) / 9, 0), 1)
        if t < 0.5 {
            let k = t / 0.5
            return Color(red: 1.0, green: 0.45 + 0.55 * k, blue: 0.45 + 0.55 * k).opacity(0.72)
        }
        let k = (t - 0.5) / 0.5
        return Color(red: 1.0 - 0.48 * k, green: 1.0, blue: 1.0 - 0.48 * k).opacity(0.72)
    }
}

private struct YearProgressDonut: View {
    let progress: Double
    let tintColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tintColor.opacity(0.18), lineWidth: 11)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.28))
        }
        .frame(width: 78, height: 78)
        .padding(4)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
