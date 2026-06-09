import Foundation
import SwiftUI

/// 앱 전체 상태를 들고 있는 관찰 가능한 저장소.
/// JSON 파일(~/Library/Application Support/Planner/data.json)로 영속화한다.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var data = PlannerData()

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

    private func save() {
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
