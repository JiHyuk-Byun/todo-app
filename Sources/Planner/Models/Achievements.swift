import Foundation

/// 업적 배지 정의.
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    /// 현재 달성 여부(Store 지표로 계산).
    let isUnlocked: @MainActor (Store) -> Bool
}

enum Achievements {
    static let all: [Badge] = [
        // MARK: 할 일 완료
        Badge(id: "todo1", title: "첫걸음", detail: "할 일을 처음 완료",
              systemImage: "checkmark.circle.fill") { $0.completedTodoCount() >= 1 },
        Badge(id: "todo10", title: "시동", detail: "할 일 10개 완료",
              systemImage: "checklist") { $0.completedTodoCount() >= 10 },
        Badge(id: "todo50", title: "성실함", detail: "할 일 50개 완료",
              systemImage: "checklist.checked") { $0.completedTodoCount() >= 50 },
        Badge(id: "todo100", title: "꾸준함", detail: "할 일 100개 완료",
              systemImage: "rosette") { $0.completedTodoCount() >= 100 },
        Badge(id: "todo250", title: "근면", detail: "할 일 250개 완료",
              systemImage: "trophy.fill") { $0.completedTodoCount() >= 250 },
        Badge(id: "todo500", title: "대가", detail: "할 일 500개 완료",
              systemImage: "trophy.circle.fill") { $0.completedTodoCount() >= 500 },

        // MARK: 완벽한 하루
        Badge(id: "perfect1", title: "완벽한 하루", detail: "하루 할 일을 모두 완료",
              systemImage: "star.fill") { $0.perfectDayCount() >= 1 },
        Badge(id: "perfect7", title: "완벽한 일주일", detail: "완벽한 하루 7번",
              systemImage: "star.circle.fill") { $0.perfectDayCount() >= 7 },
        Badge(id: "perfect30", title: "완벽주의자", detail: "완벽한 하루 30번",
              systemImage: "sparkle.magnifyingglass") { $0.perfectDayCount() >= 30 },

        // MARK: 연속(스트릭)
        Badge(id: "streak3", title: "불씨", detail: "할 일 3일 연속 100%",
              systemImage: "flame") { $0.todoStreak() >= 3 },
        Badge(id: "streak7", title: "일주일 불꽃", detail: "할 일 7일 연속 100%",
              systemImage: "flame.fill") { $0.todoStreak() >= 7 },
        Badge(id: "streak14", title: "2주 불꽃", detail: "할 일 14일 연속 100%",
              systemImage: "flame.fill") { $0.todoStreak() >= 14 },
        Badge(id: "streak30", title: "한 달 불꽃", detail: "할 일 30일 연속 100%",
              systemImage: "flame.circle.fill") { $0.todoStreak() >= 30 },
        Badge(id: "streak100", title: "백일 불꽃", detail: "할 일 100일 연속 100%",
              systemImage: "flame.circle.fill") { $0.todoStreak() >= 100 },

        // MARK: 목표
        Badge(id: "goal1", title: "목표 달성", detail: "목표를 처음 완료",
              systemImage: "target") { $0.completedGoalCount() >= 1 },
        Badge(id: "goal25", title: "목표 사냥꾼", detail: "목표 25개 완료",
              systemImage: "scope") { $0.completedGoalCount() >= 25 },
        Badge(id: "goal100", title: "비전 실현가", detail: "목표 100개 완료",
              systemImage: "mountain.2.fill") { $0.completedGoalCount() >= 100 },

        // MARK: 말씀 암송 — credit
        Badge(id: "verse1", title: "첫 암송", detail: "말씀을 처음 완벽 암송",
              systemImage: "book.fill") { $0.totalCredits() >= 1 },
        Badge(id: "credit50", title: "암송 50", detail: "누적 암송 credit 50",
              systemImage: "text.book.closed.fill") { $0.totalCredits() >= 50 },
        Badge(id: "credit100", title: "암송 100", detail: "누적 암송 credit 100",
              systemImage: "sparkles") { $0.totalCredits() >= 100 },
        Badge(id: "credit500", title: "암송 500", detail: "누적 암송 credit 500",
              systemImage: "wand.and.stars") { $0.totalCredits() >= 500 },

        // MARK: 말씀 암송 — 연속/마스터/권수
        Badge(id: "vstreak3", title: "말씀 불씨", detail: "말씀 3일 연속 암송",
              systemImage: "book.closed") { $0.verseStreak() >= 3 },
        Badge(id: "vstreak7", title: "말씀 7일", detail: "말씀 7일 연속 암송",
              systemImage: "book.closed.fill") { $0.verseStreak() >= 7 },
        Badge(id: "vstreak30", title: "말씀 한 달", detail: "말씀 30일 연속 암송",
              systemImage: "books.vertical.fill") { $0.verseStreak() >= 30 },
        Badge(id: "vmaster10", title: "말씀 마스터", detail: "한 말씀을 10회 완벽 암송",
              systemImage: "crown.fill") { $0.maxVerseCredits() >= 10 },
        Badge(id: "vmaster25", title: "말씀 대가", detail: "한 말씀을 25회 완벽 암송",
              systemImage: "crown") { $0.maxVerseCredits() >= 25 },
        Badge(id: "verses5", title: "다독", detail: "서로 다른 말씀 5개 암송",
              systemImage: "books.vertical") { $0.versesRecitedCount() >= 5 },
        Badge(id: "verses25", title: "말씀 수집가", detail: "서로 다른 말씀 25개 암송",
              systemImage: "building.columns.fill") { $0.versesRecitedCount() >= 25 }
    ]

    static func badge(id: String) -> Badge? { all.first { $0.id == id } }
}
