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
    @State private var rowFramesByIndex: [Int: CGRect] = [:]
    @State private var tableViewportFrame: CGRect = .zero
    @State private var lastAutoScrollTargetRow: Int?
    @State private var lastAutoScrollTimestamp: Date = .distantPast

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
    private let overallPastelOrange = Color(red: 1.00, green: 0.82, blue: 0.58).opacity(0.62)
    private let yGridStroke = StrokeStyle(lineWidth: 0.45, dash: [6, 4])

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
            let tablePanelWidth = bottomRowUsableWidth * 0.72
            let miniPanelWidth = bottomRowUsableWidth * 0.28
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
                        width: .fixed(3.6)
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
                    AxisGridLine(stroke: yGridStroke)
                        .foregroundStyle(Color.gray.opacity(0.20))
                    AxisTick()
                    AxisValueLabel()
                        .foregroundStyle(navy)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .chartXAxis {
                AxisMarks(values: monthMidTickDates) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .frame(minWidth: 28, alignment: .center)
                        }
                    }
                    .foregroundStyle(navy)
                    .font(.system(size: 13, weight: .bold))
                    .offset(y: 12)
                }
                AxisMarks(values: dayTickDatesForExistingData) { value in
                    AxisTick(length: 3)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dayTickLabel(for: date))
                        }
                    }
                        .foregroundStyle(navy)
                        .font(.system(size: 8, weight: .bold))
                        .offset(y: 2)
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
                                        .font(.callout.weight(.bold))
                                        .foregroundStyle(lime)
                                    Spacer()
                                    Image(systemName: expandedGroups.contains(group.title) ? "chevron.down" : "chevron.right")
                                        .foregroundStyle(lime)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 20)
                                .background(navy)
                            }
                            .buttonStyle(.plain)

                            if expandedGroups.contains(group.title) {
                                ForEach(group.metrics, id: \.rawValue) { metric in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(metric.rawValue)
                                            .font(.callout.weight(.bold))
                                            .foregroundStyle(navy)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(minHeight: 18)
                                            .background(lime)
                                            .overlay(Rectangle().stroke(navy.opacity(0.2), lineWidth: 0.5))
                                        Chart(store.scoredEntries) { point in
                                            BarMark(
                                                x: .value("Date", point.date),
                                                yStart: .value("Baseline", 1),
                                                yEnd: .value(metric.rawValue, valueForMetric(metric, on: point.id)),
                                                width: .fixed(1.6)
                                            )
                                            .foregroundStyle(barBlue)
                                        }
                                        .chartYScale(domain: 0.8...10.4)
                                        .chartXScale(domain: yearDomain)
                                        .chartYAxis {
                                            AxisMarks(position: .leading, values: Array(1...10)) { _ in
                                                AxisGridLine(stroke: yGridStroke)
                                                    .foregroundStyle(Color.gray.opacity(0.20))
                                                AxisTick()
                                                AxisValueLabel()
                                                    .font(.system(size: 4, weight: .bold))
                                                    .foregroundStyle(navy)
                                            }
                                        }
                                        .chartXAxis {
                                            AxisMarks(values: monthTickDates) { _ in
                                                AxisTick(length: 2)
                                                AxisValueLabel(format: .dateTime.month(.narrow))
                                                    .font(.system(size: 6, weight: .bold))
                                                    .foregroundStyle(navy)
                                                    .offset(y: 2)
                                            }
                                        }
                                        .chartPlotStyle { plotArea in
                                            plotArea.clipped()
                                        }
                                        .frame(height: 94)
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
        let cellHeight: CGFloat = 38
        /// Inner width after the panel’s own horizontal padding (see `.padding(12)` below).
        let contentWidth = max(availableWidth - 24, 280)
        let numericColumnsCount = CGFloat(tableMetrics.count + 1)
        let metricsTotalWidth = max(contentWidth - dateColumnWidth, 0)
        let metricCellWidth = metricsTotalWidth > 0
            ? metricsTotalWidth / numericColumnsCount
            : 24
        let overallWidth = metricCellWidth
        let tableWidth = dateColumnWidth + (CGFloat(tableMetrics.count) * metricCellWidth) + overallWidth
        let scrollSpaceName = "tableVerticalScrollSpace"

        return VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { reader in
                ScrollView(.vertical) {
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
                                .background(
                                    GeometryReader { rowProxy in
                                        Color.clear.preference(
                                            key: RowFramePreferenceKey.self,
                                            value: [rowIndex: rowProxy.frame(in: .named(scrollSpaceName))]
                                        )
                                    }
                                )
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
                    .frame(width: tableWidth, alignment: .leading)
                }
                .coordinateSpace(name: scrollSpaceName)
                .background(
                    GeometryReader { viewportProxy in
                        Color.clear.preference(
                            key: TableViewportPreferenceKey.self,
                            value: viewportProxy.frame(in: .named(scrollSpaceName))
                        )
                    }
                )
                .onPreferenceChange(RowFramePreferenceKey.self) { rowFramesByIndex = $0 }
                .onPreferenceChange(TableViewportPreferenceKey.self) { tableViewportFrame = $0 }
                .onAppear {
                    guard !didScrollTableToBottom, let lastDate = dates.last else { return }
                    didScrollTableToBottom = true
                    DispatchQueue.main.async {
                        reader.scrollTo(lastDate, anchor: .bottom)
                    }
                }
                .onChange(of: focusedCell) { _, newFocusedCell in
                    maybeNudgeTableScroll(
                        focusedCell: newFocusedCell,
                        dates: dates,
                        cellHeight: cellHeight,
                        reader: reader
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
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

    private func maybeNudgeTableScroll(
        focusedCell: CellID?,
        dates: [Date],
        cellHeight: CGFloat,
        reader: ScrollViewProxy
    ) {
        guard let focusedCell else {
            lastAutoScrollTargetRow = nil
            return
        }
        guard let focusedRowFrame = rowFramesByIndex[focusedCell.row], !tableViewportFrame.isNull else { return }

        let threshold = cellHeight * 0.5
        let minInterval: TimeInterval = 0.08
        var targetRow: Int?
        var anchor: UnitPoint = .center

        if focusedRowFrame.minY < tableViewportFrame.minY + threshold {
            targetRow = max(0, focusedCell.row - 1)
            anchor = .top
        } else if focusedRowFrame.maxY > tableViewportFrame.maxY - threshold {
            targetRow = min(dates.count - 1, focusedCell.row + 1)
            anchor = .bottom
        }

        guard let targetRow else {
            lastAutoScrollTargetRow = nil
            return
        }
        guard targetRow != focusedCell.row else { return }

        let now = Date()
        if lastAutoScrollTargetRow == targetRow,
           now.timeIntervalSince(lastAutoScrollTimestamp) < minInterval {
            return
        }

        lastAutoScrollTargetRow = targetRow
        lastAutoScrollTimestamp = now
        withAnimation(.easeOut(duration: 0.12)) {
            reader.scrollTo(dates[targetRow], anchor: anchor)
        }
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
                    isReadOnly: ScoringEngine.isLegacySubjectiveSyncDate(date) && metric == .subjectiveRating,
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
                .background(overallPastelOrange)
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
        let latest = calendar.startOfDay(for: Date())
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

    private var monthMidTickDates: [Date] {
        let calendar = Calendar.current
        return monthTickDates.compactMap { start in
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: start),
                month: calendar.component(.month, from: start),
                day: 15
            ))
        }
    }

    private var dayTickDatesForExistingData: [Date] {
        dayTickSpecsForExistingData.map(\.date)
    }

    private var dayTickLabelByDate: [Date: String] {
        Dictionary(uniqueKeysWithValues: dayTickSpecsForExistingData.map { ($0.date, $0.label) })
    }

    private var dayTickSpecsForExistingData: [(date: Date, label: String)] {
        let calendar = Calendar.current
        let scoredDates = store.scoredEntries.map(\.date).sorted()
        guard let firstScoredDate = scoredDates.first, let lastScoredDate = scoredDates.last else { return [] }

        let start = calendar.startOfDay(for: firstScoredDate)
        let end = calendar.startOfDay(for: lastScoredDate)
        guard let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) else { return [] }

        let standardDays = [5, 10, 15, 20, 25]
        var specs: [(date: Date, label: String)] = []
        var monthStart = firstMonth

        while monthStart <= end {
            let year = calendar.component(.year, from: monthStart)
            let month = calendar.component(.month, from: monthStart)

            for day in standardDays {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                let normalized = calendar.startOfDay(for: date)
                if normalized >= start && normalized <= end {
                    specs.append((date: normalized, label: String(day)))
                }
            }

            // February special case: place the month-end label between Feb 25 and Mar 5.
            if month == 2,
               let monthRange = calendar.range(of: .day, in: .month, for: monthStart),
               let day25 = calendar.date(from: DateComponents(year: year, month: 2, day: 25)),
               let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart),
               let day5NextMonth = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: nextMonthStart),
                month: calendar.component(.month, from: nextMonthStart),
                day: 5
               )) {
                let midpoint = day25.addingTimeInterval(day5NextMonth.timeIntervalSince(day25) / 2.0)
                let normalizedMidpoint = calendar.startOfDay(for: midpoint)
                if normalizedMidpoint >= start && normalizedMidpoint <= end {
                    specs.append((date: normalizedMidpoint, label: String(monthRange.count)))
                }
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = nextMonth
        }

        // Keep one label per date and preserve chronological ordering.
        let deduped = Dictionary(specs.map { ($0.date, $0.label) }, uniquingKeysWith: { first, _ in first })
        return deduped.keys.sorted().compactMap { date in
            guard let label = deduped[date] else { return nil }
            return (date: date, label: label)
        }
    }

    private func dayTickLabel(for date: Date) -> String {
        let normalized = Calendar.current.startOfDay(for: date)
        return dayTickLabelByDate[normalized] ?? String(Calendar.current.component(.day, from: normalized))
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

private struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TableViewportPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private enum MoveDirection {
    case right
    case left
    case down
    case up
}

private struct NumericMetricCell: View {
    private let heatLowDark = Color(red: 0.87, green: 0.30, blue: 0.30)
    private let heatLowSoft = Color(red: 1.0, green: 0.58, blue: 0.58)
    private let heatMid = Color(red: 1.0, green: 1.0, blue: 1.0)
    private let heatHighSoft = Color(red: 0.72, green: 1.0, blue: 0.72)
    private let heatHighDark = Color(red: 0.34, green: 0.78, blue: 0.34)
    @State private var text: String
    @State private var typedBuffer = ""
    @State private var shouldReplaceOnNextDigit = true
    let value: Double
    var isReadOnly: Bool = false
    let isFocused: Bool
    let onFocus: () -> Void
    let onCommit: (Double) -> Void
    let onNavigate: (MoveDirection) -> Void

    init(
        value: Double,
        isReadOnly: Bool = false,
        isFocused: Bool,
        onFocus: @escaping () -> Void,
        onCommit: @escaping (Double) -> Void,
        onNavigate: @escaping (MoveDirection) -> Void
    ) {
        self.value = value
        self.isReadOnly = isReadOnly
        self.isFocused = isFocused
        self.onFocus = onFocus
        self.onCommit = onCommit
        self.onNavigate = onNavigate
        _text = State(initialValue: String(format: "%.1f", value))
    }

    var body: some View {
        ZStack {
            heatColor(for: value)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .focusable()
        .overlay(Rectangle().stroke(isFocused && !isReadOnly ? Color.blue : Color.blue.opacity(0.2), lineWidth: isFocused && !isReadOnly ? 1.5 : 0.5))
        .onTapGesture {
            guard !isReadOnly else { return }
            shouldReplaceOnNextDigit = true
            typedBuffer = ""
            onFocus()
        }
        .onAppear { text = String(format: "%.0f", value.rounded()) }
        .onChange(of: value) { _, newValue in
            text = String(format: "%.0f", newValue.rounded())
            if !isFocused {
                shouldReplaceOnNextDigit = true
                typedBuffer = ""
            }
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                shouldReplaceOnNextDigit = true
                typedBuffer = ""
            } else if !isReadOnly {
                commitValue()
            } else {
                text = String(format: "%.0f", value.rounded())
                shouldReplaceOnNextDigit = true
                typedBuffer = ""
            }
        }
        .onKeyPress { keyPress in
            guard isFocused, !isReadOnly else { return .ignored }
            return handleCharacterKeyPress(keyPress)
        }
        .onSubmit {
            if !isReadOnly { commitValue() }
            onNavigate(.right)
        }
        .onKeyPress(.tab) {
            if !isReadOnly { commitValue() }
            onNavigate(.right)
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !isReadOnly { commitValue() }
            onNavigate(.up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !isReadOnly { commitValue() }
            onNavigate(.down)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            onNavigate(.left)
            shouldReplaceOnNextDigit = true
            typedBuffer = ""
            return .handled
        }
        .onKeyPress(.rightArrow) {
            onNavigate(.right)
            shouldReplaceOnNextDigit = true
            typedBuffer = ""
            return .handled
        }
    }

    private func handleCharacterKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard let character = keyPress.characters.first else { return .ignored }

        if character.isWholeNumber {
            if shouldReplaceOnNextDigit {
                typedBuffer = String(character)
                shouldReplaceOnNextDigit = false
            } else if typedBuffer.count < 2 {
                typedBuffer.append(character)
            } else {
                typedBuffer = String(character)
            }
            applyBufferIfValid()
            return .handled
        }

        if character == "\u{8}" || character == "\u{7F}" {
            if shouldReplaceOnNextDigit {
                typedBuffer = text
                shouldReplaceOnNextDigit = false
            }
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
            if typedBuffer.isEmpty {
                text = ""
            } else {
                applyBufferIfValid()
            }
            return .handled
        }

        return .ignored
    }

    private func applyBufferIfValid() {
        guard !isReadOnly else { return }
        guard let parsed = Double(typedBuffer.replacingOccurrences(of: ",", with: ".")) else { return }
        let clamped = min(max(parsed, 1), 10).rounded()
        text = String(format: "%.0f", clamped)
        onCommit(clamped)
    }

    private func commitValue() {
        guard !isReadOnly else { return }
        guard let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) else {
            text = String(format: "%.0f", value.rounded())
            shouldReplaceOnNextDigit = true
            typedBuffer = ""
            return
        }
        let clamped = min(max(parsed, 1), 10).rounded()
        text = String(format: "%.0f", clamped)
        typedBuffer = text
        shouldReplaceOnNextDigit = true
        onCommit(clamped)
    }

    private func heatColor(for value: Double) -> Color {
        let t = min(max((value - 1) / 9, 0), 1)
        let lowExtremeEnd = 2.0 / 9.0    // values 1-3
        let highExtremeStart = 7.0 / 9.0 // values 8-10

        if t <= lowExtremeEnd {
            let k = t / lowExtremeEnd
            return blendedColor(from: heatLowDark, to: heatLowSoft, fraction: k).opacity(0.78)
        }
        if t < 0.5 {
            let k = (t - lowExtremeEnd) / (0.5 - lowExtremeEnd)
            return blendedColor(from: heatLowSoft, to: heatMid, fraction: k).opacity(0.74)
        }
        if t < highExtremeStart {
            let k = (t - 0.5) / (highExtremeStart - 0.5)
            return blendedColor(from: heatMid, to: heatHighSoft, fraction: k).opacity(0.74)
        }

        let k = (t - highExtremeStart) / (1.0 - highExtremeStart)
        return blendedColor(from: heatHighSoft, to: heatHighDark, fraction: k).opacity(0.78)
    }

    private func blendedColor(from: Color, to: Color, fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        #if canImport(AppKit)
        let fromNS = NSColor(from).usingColorSpace(.sRGB) ?? .black
        let toNS = NSColor(to).usingColorSpace(.sRGB) ?? .black
        #else
        let fromNS = NSColor.black
        let toNS = NSColor.black
        #endif

        var fromR: CGFloat = 0
        var fromG: CGFloat = 0
        var fromB: CGFloat = 0
        var fromA: CGFloat = 0
        var toR: CGFloat = 0
        var toG: CGFloat = 0
        var toB: CGFloat = 0
        var toA: CGFloat = 0

        fromNS.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        toNS.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

        let red = fromR + (toR - fromR) * f
        let green = fromG + (toG - fromG) * f
        let blue = fromB + (toB - fromB) * f
        let alpha = fromA + (toA - fromA) * f

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

private struct YearProgressDonut: View {
    let progress: Double
    let tintColor: Color
    private let ringLineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(tintColor.opacity(0.18), lineWidth: ringLineWidth)
                .padding(ringLineWidth / 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .padding(ringLineWidth / 2)
                .rotationEffect(Angle.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.28))
        }
        .frame(width: 162, height: 162)
        .padding(4)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
