import Foundation
import SwiftUI

/// 앱 전체 상태를 들고 있는 관찰 가능한 저장소.
/// JSON 파일(~/Library/Application Support/Planner/data.json)로 영속화한다.
@MainActor
final class Store: ObservableObject {
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

    /// 메뉴바 라벨용: 오늘의 (완료, 전체) 개수. 상태를 변경하지 않는다.
    func todayCounts() -> (done: Int, total: Int) {
        let today = calendar.startOfDay(for: Date())
        let items = data.todos.filter { calendar.isDate($0.day, inSameDayAs: today) }
        return (items.filter(\.isDone).count, items.count)
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

    // MARK: - Queries

    /// 해당 날짜의 todo 목록. 먼저 반복 규칙으로부터 빠진 todo를 생성(materialize)한 뒤 반환한다.
    func todos(on day: Date) -> [TodoItem] {
        materializeRecurring(for: day)
        let target = calendar.startOfDay(for: day)
        return data.todos
            .filter { calendar.isDate($0.day, inSameDayAs: target) }
            // 체크해도 위치가 바뀌지 않도록 생성순으로만 정렬한다.
            .sorted { $0.createdAt < $1.createdAt }
    }

    func todaysTodos() -> [TodoItem] {
        todos(on: Date())
    }

    var rules: [RecurringRule] {
        data.rules.sorted { $0.title < $1.title }
    }

    // MARK: - Todo mutations

    func addTodo(title: String, on day: Date, notes: String = "") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, notes: notes, day: calendar.startOfDay(for: day))
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
        data.todos.removeAll { $0.id == todo.id }
        save()
    }

    // MARK: - Recurring rule mutations

    func addRule(_ rule: RecurringRule) {
        data.rules.append(rule)
        save()
    }

    func update(_ rule: RecurringRule) {
        guard let idx = data.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        data.rules[idx] = rule
        // 비활성화/규칙 변경 시, 아직 완료되지 않은 미래의 자동생성 todo를 정리한다.
        save()
    }

    func deleteRule(_ rule: RecurringRule) {
        data.rules.removeAll { $0.id == rule.id }
        // 이 규칙으로 만들어졌고 아직 완료 안 한 todo도 함께 제거.
        data.todos.removeAll { $0.recurringID == rule.id && !$0.isDone }
        save()
    }

    // MARK: - Recurring materialization

    /// 주어진 날짜에 대해, 활성 반복 규칙 중 아직 todo가 만들어지지 않은 것을 생성한다.
    private func materializeRecurring(for day: Date) {
        let target = calendar.startOfDay(for: day)
        var changed = false
        for rule in data.rules where rule.occurs(on: target, calendar: calendar) {
            let exists = data.todos.contains {
                $0.recurringID == rule.id && calendar.isDate($0.day, inSameDayAs: target)
            }
            if !exists {
                let item = TodoItem(
                    title: rule.title,
                    day: target,
                    recurringID: rule.id
                )
                data.todos.append(item)
                changed = true
            }
        }
        if changed { save() }
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
