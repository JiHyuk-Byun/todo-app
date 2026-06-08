import Foundation

// MARK: - Todo

/// 특정 날짜에 속한 하나의 할 일.
struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    /// 이 todo가 속한 날짜 (시각은 무시, 자정 기준으로 정규화해서 저장).
    var day: Date
    var isDone: Bool = false
    var createdAt: Date = Date()
    /// 반복 규칙으로부터 생성된 경우 그 규칙의 id.
    var recurringID: UUID? = nil
}

// MARK: - Recurring rule

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "매일"
        case .weekly: return "매주"
        }
    }
}

/// "매일 운동"처럼 반복되는 할 일을 정의하는 규칙.
/// 실제 todo는 해당 날짜를 열어볼 때 이 규칙으로부터 생성된다.
struct RecurringRule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var frequency: Frequency = .daily
    /// weekly일 때 반복 요일. 1=일요일 ... 7=토요일 (Calendar.component(.weekday)).
    var weekdays: Set<Int> = []
    var startDay: Date
    var isActive: Bool = true

    /// 주어진 날짜에 이 규칙이 발동하는지 여부.
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedStart = calendar.startOfDay(for: startDay)
        guard normalizedDay >= normalizedStart else { return false }

        switch frequency {
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: normalizedDay)
            return weekdays.contains(weekday)
        }
    }
}

// MARK: - Persisted container

/// 디스크에 저장되는 전체 상태.
struct PlannerData: Codable {
    var todos: [TodoItem] = []
    var rules: [RecurringRule] = []
}
