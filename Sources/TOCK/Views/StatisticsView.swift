import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var appState: AppState

    private var selectedCategory: FocusCategory? {
        guard let categoryID = appState.selectedStatisticsCategoryID else { return nil }
        return appState.categories.first { $0.id == categoryID }
    }

    private var rangeSessions: [FocusSessionRecord] {
        appState.focusSessions.filter { record in
            isInSelectedRange(record.endedAt)
        }
    }

    private var filteredSessions: [FocusSessionRecord] {
        rangeSessions.filter { record in
            guard let categoryID = appState.selectedStatisticsCategoryID else { return true }
            return record.categoryID == categoryID
        }
    }

    private var displayedSeconds: Int {
        let sessionSeconds = filteredSessions.reduce(0) { $0 + $1.durationSeconds }
        if sessionSeconds > 0 {
            return sessionSeconds
        }

        guard appState.selectedStatisticsRange == .day else { return 0 }

        if let selectedCategory {
            return selectedCategory.todayTotalSeconds
        }

        return appState.todayFocusSeconds
    }

    private var displayedRecordCount: Int {
        let count = filteredSessions.count
        return count > 0 ? count : (displayedSeconds > 0 ? 1 : 0)
    }

    private var categoryTotals: [CategoryTotal] {
        appState.categories.compactMap { category in
            if let selectedCategoryID = appState.selectedStatisticsCategoryID, selectedCategoryID != category.id {
                return nil
            }

            let sessionSeconds = rangeSessions
                .filter { $0.categoryID == category.id }
                .reduce(0) { $0 + $1.durationSeconds }
            let seconds = sessionSeconds > 0 ? sessionSeconds : dayFallbackSeconds(for: category)

            guard seconds > 0 else { return nil }
            return CategoryTotal(
                id: category.id,
                name: category.name,
                color: category.color,
                seconds: seconds
            )
        }
        .sorted { $0.seconds > $1.seconds }
    }

    private var hourlySeconds: [Int] {
        var buckets = Array(repeating: 0, count: 24)
        filteredSessions.forEach { record in
            add(record: record, to: &buckets)
        }
        return buckets
    }

    private var taskTotals: [TaskTotal] {
        var totals: [String: Int] = [:]

        filteredSessions.forEach { record in
            totals[record.taskName, default: 0] += record.durationSeconds
        }

        if totals.isEmpty, appState.selectedStatisticsRange == .day {
            let categories = selectedCategory.map { [$0] } ?? appState.categories
            categories.forEach { category in
                category.visibleTasks.forEach { task in
                    if task.todayDurationSeconds > 0 {
                        totals[task.name, default: 0] += task.todayDurationSeconds
                    }
                }
            }
        }

        return totals
            .map { TaskTotal(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    private var heatmapDays: [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<30).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let seconds = appState.focusSessions
                .filter { record in
                    calendar.isDate(record.endedAt, inSameDayAs: date)
                        && (appState.selectedStatisticsCategoryID == nil || appState.selectedStatisticsCategoryID == record.categoryID)
                }
                .reduce(0) { $0 + $1.durationSeconds }

            return DayTotal(date: date, seconds: seconds)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .padding(.top, 36)

            overviewCard
            heatmapCard

            HStack(spacing: 24) {
                taskShareCard
                detailCard
            }

            Spacer()
        }
        .padding(.horizontal, 34)
    }

    private var header: some View {
        HStack {
            Text("统计")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primaryText)

            Spacer()

            HStack(spacing: 0) {
                ForEach(StatisticsRange.allCases) { range in
                    Button {
                        appState.selectedStatisticsRange = range
                    } label: {
                        Text(range.rawValue)
                            .statTab(isSelected: appState.selectedStatisticsRange == range)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 158, height: 38)
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .stroke(Color.line)
            }

            categoryMenu
        }
    }

    private var categoryMenu: some View {
        Menu {
            Button("全部分类") {
                appState.selectStatisticsCategory(id: nil)
            }

            Divider()

            ForEach(appState.categories) { category in
                Button(category.name) {
                    appState.selectStatisticsCategory(id: category.id)
                }
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(selectedCategory?.color ?? Color.tockGreen)
                    .frame(width: 14, height: 14)
                Text(selectedCategory?.name ?? "全部分类")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 104, height: 38)
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .stroke(Color.line)
            }
        }
        .buttonStyle(.plain)
    }

    private var overviewCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 12) {
                Text("专注时间")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text(DurationText.chinese(displayedSeconds))
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color.primaryText)
                Text(rangeDescription)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("专注记录")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text("\(displayedRecordCount)段")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.primaryText)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("平均时长")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text(DurationText.compact(displayedSeconds / max(displayedRecordCount, 1)))
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.primaryText)
            }
        }
        .padding(28)
        .frame(height: 142)
        .cardStyle()
    }

    private var heatmapCard: some View {
        HStack {
            Text("近 30 天专注分布")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryText)

            Spacer()

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 10), count: 10), spacing: 10) {
                ForEach(heatmapDays) { day in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(heatmapColor(for: day.seconds))
                        .frame(width: 18, height: 18)
                        .help("\(Self.dayFormatter.string(from: day.date)) \(DurationText.compact(day.seconds))")
                }
            }
            .frame(width: 270)
        }
        .padding(28)
        .frame(height: 136)
        .cardStyle()
    }

    private var taskShareCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(appState.selectedStatisticsRange.title)分类占比")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryText)

            if displayedSeconds == 0 {
                StatisticsEmptyState(text: "开始一段专注后，这里会出现分类占比。")
            } else {
                HStack {
                    DonutChart(totals: categoryTotals, totalSeconds: displayedSeconds)
                        .frame(width: 86, height: 86)

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(categoryTotals.prefix(3)) { total in
                            LegendDot(color: total.color, title: total.name)
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 224, height: 150)
        .cardStyle()
    }

    @ViewBuilder
    private var detailCard: some View {
        if appState.selectedStatisticsRange == .day {
            hourlyCard
        } else {
            taskRankingCard
        }
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今日小时分布")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryText)

            if hourlySeconds.reduce(0, +) == 0 {
                StatisticsEmptyState(text: "今天还没有专注记录。")
            } else {
                HStack(alignment: .bottom, spacing: 3) {
                    let maxSeconds = max(hourlySeconds.max() ?? 0, 1)

                    ForEach(hourlySeconds.indices, id: \.self) { hour in
                        let seconds = hourlySeconds[hour]
                        let height = seconds == 0
                            ? CGFloat(5)
                            : max(CGFloat(8), CGFloat(seconds) / CGFloat(maxSeconds) * 78)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(seconds == 0 ? Color.line : barColor(for: seconds))
                            .frame(width: 5, height: height)
                            .help("\(hour):00 \(DurationText.compact(seconds))")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(28)
        .frame(width: 224, height: 150)
        .cardStyle()
    }

    private var taskRankingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(appState.selectedStatisticsRange.title)任务排行")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryText)

            if taskTotals.isEmpty {
                StatisticsEmptyState(text: "有记录后，会看到最常投入的任务。")
            } else {
                let maxSeconds = max(taskTotals.first?.seconds ?? 0, 1)

                VStack(spacing: 10) {
                    ForEach(taskTotals.prefix(3)) { task in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(task.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text(DurationText.compact(task.seconds))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondaryText)
                            }

                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.tockGreen.opacity(0.75))
                                    .frame(width: proxy.size.width * CGFloat(task.seconds) / CGFloat(maxSeconds))
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 224, height: 150)
        .cardStyle()
    }

    private var rangeDescription: String {
        let calendar = Calendar.current
        let now = Date()

        switch appState.selectedStatisticsRange {
        case .day:
            return Self.dateFormatter.string(from: now)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return "本周" }
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(Self.shortDateFormatter.string(from: interval.start)) - \(Self.shortDateFormatter.string(from: end))"
        case .month:
            return Self.monthFormatter.string(from: now)
        case .year:
            return Self.yearFormatter.string(from: now)
        }
    }

    private func dayFallbackSeconds(for category: FocusCategory) -> Int {
        guard appState.selectedStatisticsRange == .day else { return 0 }
        return category.todayTotalSeconds
    }

    private func isInSelectedRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch appState.selectedStatisticsRange {
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }

    private func add(record: FocusSessionRecord, to buckets: inout [Int]) {
        let calendar = Calendar.current
        var cursor = record.startedAt
        let end = record.endedAt

        while cursor < end {
            guard let hourInterval = calendar.dateInterval(of: .hour, for: cursor) else { break }
            let segmentEnd = min(hourInterval.end, end)
            let hour = calendar.component(.hour, from: cursor)
            buckets[hour] += max(0, Int(segmentEnd.timeIntervalSince(cursor)))

            guard segmentEnd > cursor else { break }
            cursor = segmentEnd
        }
    }

    private func heatmapColor(for seconds: Int) -> Color {
        switch seconds {
        case 0:
            return Color(red: 0.86, green: 0.91, blue: 0.95)
        case 1..<(3 * 3600):
            return Color.tockGreen.opacity(0.35)
        case (3 * 3600)..<(6 * 3600):
            return Color.tockGreen.opacity(0.62)
        case (6 * 3600)..<(9 * 3600):
            return Color.tockGreen
        default:
            return Color.deepGreen
        }
    }

    private func barColor(for seconds: Int) -> Color {
        seconds >= 45 * 60 ? Color.deepGreen : Color.tockGreen.opacity(0.75)
    }
}

private struct StatisticsEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.secondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct CategoryTotal: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let seconds: Int
}

private struct TaskTotal: Identifiable {
    let name: String
    let seconds: Int

    var id: String { name }
}

private struct DayTotal: Identifiable {
    let date: Date
    let seconds: Int

    var id: Date { date }
}

private struct DonutChart: View {
    let totals: [CategoryTotal]
    let totalSeconds: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color.line, lineWidth: 16)

            ForEach(totals.indices, id: \.self) { index in
                let segment = totals[index]
                Circle()
                    .trim(from: startFraction(for: index), to: endFraction(for: index))
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("总时长")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text(DurationText.compact(totalSeconds))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.primaryText)
            }
        }
    }

    private func startFraction(for index: Int) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        let previousSeconds = totals.prefix(index).reduce(0) { $0 + $1.seconds }
        return CGFloat(previousSeconds) / CGFloat(totalSeconds)
    }

    private func endFraction(for index: Int) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        let throughSeconds = totals.prefix(index + 1).reduce(0) { $0 + $1.seconds }
        return min(1, CGFloat(throughSeconds) / CGFloat(totalSeconds))
    }
}

private struct LegendDot: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)
        }
    }
}

private extension StatisticsView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        return formatter
    }()
}

private extension Text {
    func statTab(isSelected: Bool = false) -> some View {
        self
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isSelected ? Color.primaryText : Color.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Color.tockGreen.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
