import SwiftUI

/// 스케줄러 탭.
enum SchedulerTab: String, CaseIterable, Identifiable {
    case schedule = "일정"
    case goals = "목표"
    case verse = "말씀"
    case stats = "통계"
    var id: String { rawValue }
}

/// 창 간 공유되는 가벼운 UI 상태(예: 드롭다운에서 스케줄러를 특정 탭으로 열기).
@MainActor
final class UIState: ObservableObject {
    static let shared = UIState()
    @Published var schedulerTab: SchedulerTab = .schedule
    private init() {}
}
