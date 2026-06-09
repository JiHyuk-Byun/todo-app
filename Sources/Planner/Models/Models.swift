import Foundation

// MARK: - Category

/// 할 일/목표의 분류. 영성/전문성 두 가지 고정.
enum TodoCategory: String, Codable, CaseIterable, Identifiable {
    case spirituality
    case professional

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spirituality: return "영성"
        case .professional: return "전문성"
        }
    }

    var systemImage: String {
        switch self {
        case .spirituality: return "leaf"
        case .professional: return "briefcase"
        }
    }
}

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
    /// 수동 정렬 순서. 작을수록 위.
    var sortIndex: Int = 0
    /// 영성/전문성 분류.
    var category: TodoCategory = .spirituality

    init(id: UUID = UUID(), title: String, notes: String = "", day: Date,
         isDone: Bool = false, createdAt: Date = Date(),
         recurringID: UUID? = nil, sortIndex: Int = 0,
         category: TodoCategory = .spirituality) {
        self.id = id
        self.title = title
        self.notes = notes
        self.day = day
        self.isDone = isDone
        self.createdAt = createdAt
        self.recurringID = recurringID
        self.sortIndex = sortIndex
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, day, isDone, createdAt, recurringID, sortIndex, category
    }

    // 기존 data.json(새 필드 없음)도 디코딩되도록 decodeIfPresent 사용.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        day = try c.decode(Date.self, forKey: .day)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        recurringID = try c.decodeIfPresent(UUID.self, forKey: .recurringID)
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        category = try c.decodeIfPresent(TodoCategory.self, forKey: .category) ?? .spirituality
    }
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
    /// 반복 종료일(포함). nil이면 무기한.
    var endDay: Date? = nil
    var isActive: Bool = true
    /// 사용자가 "이 날만 건너뛰기"한 날짜들(자정 정규화). 이 날엔 생성하지 않는다.
    var skippedDates: Set<Date> = []
    /// 생성되는 todo가 상속할 분류.
    var category: TodoCategory = .spirituality

    init(id: UUID = UUID(), title: String, frequency: Frequency = .daily,
         weekdays: Set<Int> = [], startDay: Date, endDay: Date? = nil,
         isActive: Bool = true, skippedDates: Set<Date> = [],
         category: TodoCategory = .spirituality) {
        self.id = id
        self.title = title
        self.frequency = frequency
        self.weekdays = weekdays
        self.startDay = startDay
        self.endDay = endDay
        self.isActive = isActive
        self.skippedDates = skippedDates
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id, title, frequency, weekdays, startDay, endDay, isActive, skippedDates, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        frequency = try c.decodeIfPresent(Frequency.self, forKey: .frequency) ?? .daily
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? []
        startDay = try c.decode(Date.self, forKey: .startDay)
        endDay = try c.decodeIfPresent(Date.self, forKey: .endDay)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        skippedDates = try c.decodeIfPresent(Set<Date>.self, forKey: .skippedDates) ?? []
        category = try c.decodeIfPresent(TodoCategory.self, forKey: .category) ?? .spirituality
    }

    /// 주어진 날짜에 이 규칙이 발동하는지 여부.
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedStart = calendar.startOfDay(for: startDay)
        guard normalizedDay >= normalizedStart else { return false }
        // 종료일 이후면 발동하지 않는다.
        if let endDay, normalizedDay > calendar.startOfDay(for: endDay) { return false }
        // 건너뛴 날짜면 생성하지 않는다.
        if skippedDates.contains(normalizedDay) { return false }

        switch frequency {
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: normalizedDay)
            return weekdays.contains(weekday)
        }
    }

    /// 주어진 날짜 이후(포함) 가장 가까운 발동일. 없으면 nil.
    func nextOccurrence(from day: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isActive else { return nil }
        var probe = calendar.startOfDay(for: day)
        // 최대 366일까지 탐색(주간 규칙이라도 1년 내 반드시 발생).
        for _ in 0..<366 {
            if occurs(on: probe, calendar: calendar) { return probe }
            guard let next = calendar.date(byAdding: .day, value: 1, to: probe) else { return nil }
            probe = next
        }
        return nil
    }
}

// MARK: - Goals

/// 목표의 기간 단위.
enum GoalHorizon: String, Codable, CaseIterable, Identifiable {
    case week
    case month
    case year
    case vision

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "이번 주"
        case .month: return "이번 달"
        case .year: return "올해"
        case .vision: return "비전"
        }
    }

    var systemImage: String {
        switch self {
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        case .year: return "target"
        case .vision: return "sparkles"
        }
    }

    /// 기간 구분용 색상(배지 등).
    var tintName: HorizonTint {
        switch self {
        case .week: return .blue
        case .month: return .green
        case .year: return .orange
        case .vision: return .purple
        }
    }
}

/// SwiftUI 비의존 색상 토큰(뷰에서 Color로 매핑).
enum HorizonTint { case blue, green, orange, purple }

/// 한 기간(periodKey)에 속한 목표 항목.
struct GoalItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var horizon: GoalHorizon
    /// 기간 식별자. week="YYYY-Www", month="YYYY-MM", year="YYYY", vision="vision".
    var periodKey: String
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    /// 영성/전문성 분류.
    var category: TodoCategory = .spirituality
    /// 상단에 고정 여부.
    var pinned: Bool = false
    /// 고정 목표들 사이의 정렬 순서.
    var pinIndex: Int = 0

    init(id: UUID = UUID(), title: String, isDone: Bool = false,
         horizon: GoalHorizon, periodKey: String, sortIndex: Int = 0,
         createdAt: Date = Date(), category: TodoCategory = .spirituality,
         pinned: Bool = false, pinIndex: Int = 0) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.horizon = horizon
        self.periodKey = periodKey
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.category = category
        self.pinned = pinned
        self.pinIndex = pinIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, title, isDone, horizon, periodKey, sortIndex, createdAt, category, pinned, pinIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        horizon = try c.decode(GoalHorizon.self, forKey: .horizon)
        periodKey = try c.decode(String.self, forKey: .periodKey)
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        category = try c.decodeIfPresent(TodoCategory.self, forKey: .category) ?? .spirituality
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        pinIndex = try c.decodeIfPresent(Int.self, forKey: .pinIndex) ?? 0
    }
}

// MARK: - Verse (말씀 암송)

/// 그날의 말씀과 암송 진행.
struct Verse: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 속한 날짜(자정 정규화).
    var day: Date
    /// 출처/참조 (예: "요한복음 3:16"). 선택.
    var reference: String = ""
    /// 외워야 할 원문.
    var text: String
    /// 완벽히 일치한 암송 횟수.
    var credits: Int = 0
    /// 전체 시도 횟수.
    var attempts: Int = 0
    var createdAt: Date = Date()

    init(id: UUID = UUID(), day: Date, reference: String = "", text: String,
         credits: Int = 0, attempts: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.day = day
        self.reference = reference
        self.text = text
        self.credits = credits
        self.attempts = attempts
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, day, reference, text, credits, attempts, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        day = try c.decode(Date.self, forKey: .day)
        reference = try c.decodeIfPresent(String.self, forKey: .reference) ?? ""
        text = try c.decode(String.self, forKey: .text)
        credits = try c.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        attempts = try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Persisted container

/// 디스크에 저장되는 전체 상태.
struct PlannerData: Codable {
    var todos: [TodoItem] = []
    var rules: [RecurringRule] = []
    var goals: [GoalItem] = []
    var verses: [Verse] = []
    /// 획득한 배지 id → 획득 시각.
    var unlockedBadges: [String: Date] = [:]

    init(todos: [TodoItem] = [], rules: [RecurringRule] = [],
         goals: [GoalItem] = [], verses: [Verse] = [],
         unlockedBadges: [String: Date] = [:]) {
        self.todos = todos
        self.rules = rules
        self.goals = goals
        self.verses = verses
        self.unlockedBadges = unlockedBadges
    }

    enum CodingKeys: String, CodingKey {
        case todos, rules, goals, verses, unlockedBadges
    }

    // 기존 data.json(goals/verses/unlockedBadges 키 없음)도 디코딩되도록.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        rules = try c.decodeIfPresent([RecurringRule].self, forKey: .rules) ?? []
        goals = try c.decodeIfPresent([GoalItem].self, forKey: .goals) ?? []
        verses = try c.decodeIfPresent([Verse].self, forKey: .verses) ?? []
        unlockedBadges = try c.decodeIfPresent([String: Date].self, forKey: .unlockedBadges) ?? [:]
    }
}
