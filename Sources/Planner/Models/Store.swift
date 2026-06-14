import Foundation
import SwiftUI

/// 앱 전체 상태를 들고 있는 관찰 가능한 저장소.
/// JSON 파일(~/Library/Application Support/Planner/data.json)로 영속화한다.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var data = PlannerData()
    /// 방금 새로 획득한 배지(연출 후 dismiss로 비움).
    @Published private(set) var justUnlocked: [Badge] = []

    private let calendar = Calendar.current
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Planner", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("data.json")
        load()
        // 실행 시점에 오늘의 반복 일정을 미리 생성해 둔다(메뉴바 카운트 정확도).
        materializeRecurring(for: Date())
        startMidnightRefresh()
    }

    private var refreshTimer: Timer?

    /// 자정을 넘겨도 "오늘"이 갱신되도록 주기적으로 새로고침한다.
    private func startMidnightRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.materializeRecurring(for: Date())
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder.planner.decode(PlannerData.self, from: raw) {
            data = decoded
        }
    }

    private var evaluatingBadges = false

    private func save() {
        writeFile()
        if !evaluatingBadges {
            evaluatingBadges = true
            checkBadges()
            evaluatingBadges = false
        }
    }

    private func writeFile() {
        guard let raw = try? JSONEncoder.planner.encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    // MARK: - Todo queries

    /// 해당 날짜의 todo 목록(정렬됨). 반복 생성은 ensureMaterialized로 분리되어 있어
    /// 이 메서드는 상태를 변경하지 않는다(뷰 렌더 중 안전).
    func todos(on day: Date) -> [TodoItem] {
        let target = calendar.startOfDay(for: day)
        return data.todos
            .filter { calendar.isDate($0.day, inSameDayAs: target) }
            .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    func todaysTodos() -> [TodoItem] {
        todos(on: Date())
    }

    /// 캘린더 점 표시용: 해당 날짜의 (전체, 완료) 개수.
    /// 아직 생성되지 않은 반복 발생분도 미완료로 포함해 정확한 점을 보장한다.
    func dayStatus(on day: Date) -> (total: Int, done: Int) {
        let target = calendar.startOfDay(for: day)
        let materialized = data.todos.filter { calendar.isDate($0.day, inSameDayAs: target) }
        var total = materialized.count
        let done = materialized.filter(\.isDone).count
        for rule in data.rules where rule.occurs(on: target, calendar: calendar) {
            let already = materialized.contains { $0.recurringID == rule.id }
            if !already { total += 1 }
        }
        return (total, done)
    }

    /// 메뉴바 라벨용: 오늘의 (완료, 전체) 개수. 상태를 변경하지 않는다.
    func todayCounts() -> (done: Int, total: Int) {
        let s = dayStatus(on: Date())
        return (s.done, s.total)
    }

    var rules: [RecurringRule] {
        data.rules.sorted { $0.title < $1.title }
    }

    // MARK: - Todo mutations

    /// 해당 날짜·카테고리의 todo만.
    func todos(on day: Date, category: TodoCategory) -> [TodoItem] {
        todos(on: day).filter { $0.category == category }
    }

    /// 날짜·카테고리별 (완료, 전체) 개수(섹션 헤더용). 머티리얼라이즈된 것만 집계.
    func dayCategoryCounts(on day: Date, category: TodoCategory) -> (done: Int, total: Int) {
        let items = todos(on: day, category: category)
        return (items.filter(\.isDone).count, items.count)
    }

    func addTodo(title: String, on day: Date, notes: String = "",
                 category: TodoCategory = .spirituality) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let target = calendar.startOfDay(for: day)
        let maxIdx = data.todos
            .filter { calendar.isDate($0.day, inSameDayAs: target) }
            .map(\.sortIndex).max() ?? -1
        let item = TodoItem(title: trimmed, notes: notes, day: target,
                            sortIndex: maxIdx + 1, category: category)
        data.todos.append(item)
        save()
    }

    func toggle(_ todo: TodoItem) {
        guard let idx = data.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        data.todos[idx].isDone.toggle()
        save()
    }

    func update(_ todo: TodoItem) {
        guard let idx = data.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        data.todos[idx] = todo
        save()
    }

    func delete(_ todo: TodoItem) {
        // 반복 생성 항목은 그냥 지우면 다시 생성되므로 skipOccurrence로 보낸다.
        if todo.recurringID != nil {
            skipOccurrence(todo)
            return
        }
        data.todos.removeAll { $0.id == todo.id }
        save()
    }

    /// 반복 생성된 todo를 "이 날만 건너뛰기" — 항목 제거 + 규칙에 건너뛴 날짜 기록(재생성 방지).
    func skipOccurrence(_ todo: TodoItem) {
        data.todos.removeAll { $0.id == todo.id }
        if let rid = todo.recurringID,
           let idx = data.rules.firstIndex(where: { $0.id == rid }) {
            data.rules[idx].skippedDates.insert(calendar.startOfDay(for: todo.day))
        }
        save()
    }

    func todo(id: UUID) -> TodoItem? { data.todos.first { $0.id == id } }

    /// 할 일을 다른 날짜로 이동(달력 드롭). 반복 생성분은 분리(원래 날짜는 건너뛰기 처리).
    func moveTodo(_ todo: TodoItem, toDay day: Date) {
        guard let idx = data.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let target = calendar.startOfDay(for: day)
        if calendar.isDate(data.todos[idx].day, inSameDayAs: target) { return }

        if let rid = data.todos[idx].recurringID {
            if let r = data.rules.firstIndex(where: { $0.id == rid }) {
                data.rules[r].skippedDates.insert(calendar.startOfDay(for: todo.day))
            }
            data.todos[idx].recurringID = nil   // 규칙에서 분리된 단독 할 일로
        }
        let maxIdx = data.todos
            .filter { calendar.isDate($0.day, inSameDayAs: target) && $0.id != todo.id }
            .map(\.sortIndex).max() ?? -1
        data.todos[idx].day = target
        data.todos[idx].sortIndex = maxIdx + 1
        save()
    }

    /// 드래그로 순서 변경(카테고리 섹션 내에서).
    func moveTodos(on day: Date, category: TodoCategory,
                   from source: IndexSet, to destination: Int) {
        var items = todos(on: day, category: category)
        items.move(fromOffsets: source, toOffset: destination)
        for (i, item) in items.enumerated() {
            if let idx = data.todos.firstIndex(where: { $0.id == item.id }) {
                data.todos[idx].sortIndex = i
            }
        }
        save()
    }

    // MARK: - Recurring rule mutations

    func addRule(_ rule: RecurringRule) {
        data.rules.append(rule)
        materializeRecurring(for: Date())
        save()
    }

    func update(_ rule: RecurringRule) {
        guard let idx = data.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        data.rules[idx] = rule
        // 규칙 변경/비활성 시 오늘 이후의 미완료 자동생성 todo를 제거 →
        // 새 스케줄로 다시 머티리얼라이즈되며 반영된다(과거/완료분은 보존).
        let today = calendar.startOfDay(for: Date())
        data.todos.removeAll {
            $0.recurringID == rule.id && !$0.isDone && calendar.startOfDay(for: $0.day) >= today
        }
        materializeRecurring(for: Date())
        save()
    }

    func deleteRule(_ rule: RecurringRule) {
        data.rules.removeAll { $0.id == rule.id }
        // 이 규칙으로 만들어졌고 아직 완료 안 한 todo도 함께 제거.
        data.todos.removeAll { $0.recurringID == rule.id && !$0.isDone }
        save()
    }

    // MARK: - Recurring materialization

    /// 주어진 날짜의 반복 발생분을 실제 todo로 생성한다(뷰의 .task/onChange에서 호출).
    func ensureMaterialized(for day: Date) {
        materializeRecurring(for: day)
    }

    /// 드롭다운을 열 때 등, "오늘" 기준을 즉시 새로고침한다(자정 경과 반영).
    func refreshNow() {
        materializeRecurring(for: Date())
        objectWillChange.send()
    }

    private func materializeRecurring(for day: Date) {
        let target = calendar.startOfDay(for: day)
        let dayItems = data.todos.filter { calendar.isDate($0.day, inSameDayAs: target) }
        var nextIndex = (dayItems.map(\.sortIndex).max() ?? -1) + 1
        var changed = false
        for rule in data.rules where rule.occurs(on: target, calendar: calendar) {
            let exists = data.todos.contains {
                $0.recurringID == rule.id && calendar.isDate($0.day, inSameDayAs: target)
            }
            if !exists {
                let item = TodoItem(title: rule.title, day: target,
                                    recurringID: rule.id, sortIndex: nextIndex,
                                    category: rule.category)
                nextIndex += 1
                data.todos.append(item)
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Goals

    /// 주어진 기간 단위의 현재 기간 식별자.
    func currentPeriodKey(_ horizon: GoalHorizon, for date: Date = Date()) -> String {
        switch horizon {
        case .week:
            let c = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
            return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
        case .month:
            let c = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        case .year:
            let c = calendar.dateComponents([.year], from: date)
            return String(format: "%04d", c.year ?? 0)
        case .vision:
            return "vision"
        }
    }

    /// 사람이 읽는 현재 기간 부제(예: "2026년 6월", "24주차").
    func periodSubtitle(_ horizon: GoalHorizon, for date: Date = Date()) -> String {
        switch horizon {
        case .week:
            let c = calendar.dateComponents([.weekOfYear], from: date)
            return "\(c.weekOfYear ?? 0)주차"
        case .month:
            return date.formatted(.dateTime.year().month())
        case .year:
            return date.formatted(.dateTime.year())
        case .vision:
            return "장기 목표"
        }
    }

    func goals(_ horizon: GoalHorizon, periodKey: String? = nil) -> [GoalItem] {
        let key = periodKey ?? currentPeriodKey(horizon)
        return data.goals
            .filter { $0.horizon == horizon && $0.periodKey == key }
            .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    /// horizon·category의 목표만(현재 기간 기본).
    func goals(_ horizon: GoalHorizon, category: TodoCategory, periodKey: String? = nil) -> [GoalItem] {
        goals(horizon, periodKey: periodKey).filter { $0.category == category }
    }

    func goalCounts(_ horizon: GoalHorizon) -> (done: Int, total: Int) {
        let items = goals(horizon)
        return (items.filter(\.isDone).count, items.count)
    }

    func goalCounts(_ horizon: GoalHorizon, category: TodoCategory) -> (done: Int, total: Int) {
        let items = goals(horizon, category: category)
        return (items.filter(\.isDone).count, items.count)
    }

    func addGoal(title: String, horizon: GoalHorizon,
                 category: TodoCategory = .spirituality) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = currentPeriodKey(horizon)
        let maxIdx = data.goals
            .filter { $0.horizon == horizon && $0.periodKey == key }
            .map(\.sortIndex).max() ?? -1
        data.goals.append(GoalItem(title: trimmed, horizon: horizon,
                                   periodKey: key, sortIndex: maxIdx + 1,
                                   category: category))
        save()
    }

    func toggleGoal(_ goal: GoalItem) {
        guard let idx = data.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        data.goals[idx].isDone.toggle()
        save()
    }

    func updateGoal(_ goal: GoalItem) {
        guard let idx = data.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        data.goals[idx] = goal
        save()
    }

    func deleteGoal(_ goal: GoalItem) {
        data.goals.removeAll { $0.id == goal.id }
        save()
    }

    func togglePinGoal(_ goal: GoalItem) {
        guard let idx = data.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        if !data.goals[idx].pinned {
            // 새로 고정 → 맨 뒤 순서로.
            let maxPin = data.goals.filter(\.pinned).map(\.pinIndex).max() ?? -1
            data.goals[idx].pinIndex = maxPin + 1
        }
        data.goals[idx].pinned.toggle()
        save()
    }

    /// 상단에 고정된 목표들(사용자 지정 순서 pinIndex).
    func pinnedGoals() -> [GoalItem] {
        data.goals
            .filter { $0.pinned }
            .sorted { ($0.pinIndex, $0.createdAt) < ($1.pinIndex, $1.createdAt) }
    }

    /// 고정 목표 드래그 정렬.
    func movePinned(from source: IndexSet, to destination: Int) {
        var items = pinnedGoals()
        items.move(fromOffsets: source, toOffset: destination)
        for (i, item) in items.enumerated() {
            if let idx = data.goals.firstIndex(where: { $0.id == item.id }) {
                data.goals[idx].pinIndex = i
            }
        }
        save()
    }

    // MARK: - 지표(성취/통계)

    func completedTodoCount() -> Int { data.todos.filter(\.isDone).count }
    func completedGoalCount() -> Int { data.goals.filter(\.isDone).count }

    /// 그날 materialized todo가 ≥1이고 전부 완료.
    func dayFullyDone(_ day: Date) -> Bool {
        let items = data.todos.filter { calendar.isDate($0.day, inSameDayAs: day) }
        return !items.isEmpty && items.allSatisfy(\.isDone)
    }

    func perfectDayCount() -> Int {
        let days = Set(data.todos.map { calendar.startOfDay(for: $0.day) })
        return days.filter { dayFullyDone($0) }.count
    }

    /// 오늘(미완료면 어제)부터 역방향으로 자격일 연속 수.
    private func streak(_ qualifies: (Date) -> Bool) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: Date())
        if !qualifies(day) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        while qualifies(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    func todoStreak() -> Int { streak { dayFullyDone($0) } }
    func verseStreak() -> Int { streak { (verse(on: $0)?.credits ?? 0) > 0 } }

    func totalCredits() -> Int { data.verses.reduce(0) { $0 + $1.credits } }
    func versesRecitedCount() -> Int { data.verses.filter { $0.credits > 0 }.count }
    func maxVerseCredits() -> Int { data.verses.map(\.credits).max() ?? 0 }

    /// 최근 7일 완료율(done/total). todo 없으면 0.
    func weeklyCompletionRate() -> Double {
        let today = calendar.startOfDay(for: Date())
        var total = 0, done = 0
        for offset in 0..<7 {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let items = data.todos.filter { calendar.isDate($0.day, inSameDayAs: d) }
            total += items.count
            done += items.filter(\.isDone).count
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    // MARK: - 배지

    private func checkBadges() {
        var newly: [Badge] = []
        for badge in Achievements.all where data.unlockedBadges[badge.id] == nil {
            if badge.isUnlocked(self) {
                data.unlockedBadges[badge.id] = Date()
                newly.append(badge)
            }
        }
        if !newly.isEmpty {
            justUnlocked.append(contentsOf: newly)
            save()   // unlockedBadges 영속(재진입 가드로 무한루프 방지)
        }
    }

    func dismissUnlocked() { justUnlocked = [] }

    /// 단일 이동(드래그앤드롭용): id를 destination 인덱스로 옮긴다.
    func movePinned(id: UUID, before destinationID: UUID?) {
        var items = pinnedGoals()
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }
        let moved = items.remove(at: from)
        if let destinationID, let to = items.firstIndex(where: { $0.id == destinationID }) {
            items.insert(moved, at: to)
        } else {
            items.append(moved)
        }
        for (i, item) in items.enumerated() {
            if let idx = data.goals.firstIndex(where: { $0.id == item.id }) {
                data.goals[idx].pinIndex = i
            }
        }
        save()
    }

    func moveGoals(_ horizon: GoalHorizon, category: TodoCategory,
                   from source: IndexSet, to destination: Int,
                   periodKey: String? = nil) {
        let key = periodKey ?? currentPeriodKey(horizon)
        var items = goals(horizon, category: category, periodKey: key)
        items.move(fromOffsets: source, toOffset: destination)
        for (i, item) in items.enumerated() {
            if let idx = data.goals.firstIndex(where: { $0.id == item.id }) {
                data.goals[idx].sortIndex = i
            }
        }
        save()
    }

    // MARK: - Verse (말씀 암송)

    func verse(on day: Date) -> Verse? {
        let target = calendar.startOfDay(for: day)
        return data.verses.first { calendar.isDate($0.day, inSameDayAs: target) }
    }

    func todayVerse() -> Verse? { verse(on: Date()) }

    /// 모든 말씀(최근 날짜 우선).
    func allVerses() -> [Verse] {
        data.verses.sorted { $0.day > $1.day }
    }

    /// 오늘을 제외한 지난 말씀(최근 우선).
    func pastVerses() -> [Verse] {
        let today = calendar.startOfDay(for: Date())
        return allVerses().filter { !calendar.isDate($0.day, inSameDayAs: today) }
    }

    /// 그날 말씀 등록/수정. text가 바뀌면 새 말씀이므로 credits/attempts 리셋.
    func setVerse(text: String, reference: String, on day: Date) {
        let target = calendar.startOfDay(for: day)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRef = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = data.verses.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: target) }) {
            if data.verses[idx].text != trimmedText {
                data.verses[idx].text = trimmedText
                data.verses[idx].credits = 0
                data.verses[idx].attempts = 0
            }
            data.verses[idx].reference = trimmedRef
        } else {
            data.verses.append(Verse(day: target, reference: trimmedRef, text: trimmedText))
        }
        save()
    }

    func deleteVerse(on day: Date) {
        let target = calendar.startOfDay(for: day)
        data.verses.removeAll { calendar.isDate($0.day, inSameDayAs: target) }
        save()
    }

    /// 암송 시도. 원문과 양끝 공백/개행만 무시하고 완전 일치하면 credit++.
    @discardableResult
    func recite(_ attempt: String, on day: Date) -> Bool {
        let target = calendar.startOfDay(for: day)
        guard let idx = data.verses.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: target) })
        else { return false }
        let correct = data.verses[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = attempt.trimmingCharacters(in: .whitespacesAndNewlines)
        data.verses[idx].attempts += 1
        let matched = !correct.isEmpty && typed == correct
        if matched { data.verses[idx].credits += 1 }
        save()
        return matched
    }
}

// MARK: - JSON helpers

extension JSONEncoder {
    static var planner: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var planner: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
