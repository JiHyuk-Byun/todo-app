import SwiftUI

extension HorizonTint {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

/// 기간(이번주/이번달/올해/비전)을 색깔 캡슐로 또렷하게 보여주는 배지.
struct HorizonChip: View {
    let horizon: GoalHorizon
    var body: some View {
        let c = horizon.tintName.color
        Text(horizon.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(c)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(c.opacity(0.18)))
    }
}

/// 상단에 고정된 목표 목록. 내용 높이에 맞추되 maxHeight를 넘으면 그 안에서만 스크롤.
/// 중첩 List 충돌을 피하려 ScrollView + VStack으로 구성하고, 행은 drag&drop으로 재정렬.
struct PinnedGoalsList: View {
    @EnvironmentObject private var store: Store
    var fixedMaxHeight: CGFloat = 240

    private let rowHeight: CGFloat = 30   // 스크롤 여부 판단용 추정값

    var body: some View {
        let pinned = store.pinnedGoals()
        if !pinned.isEmpty {
            let estimated = CGFloat(pinned.count) * rowHeight
            VStack(alignment: .leading, spacing: 2) {
                Label("고정한 목표", systemImage: "pin.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                if estimated > fixedMaxHeight {
                    ScrollView { rows(pinned) }
                        .frame(height: fixedMaxHeight)
                } else {
                    rows(pinned)   // 자연 높이 = 내용에 딱 맞음(빈 공백 없음)
                }

                Divider()
            }
        }
    }

    private func rows(_ pinned: [GoalItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(pinned) { goal in
                PinnedGoalRow(goal: goal)
                    .draggable(goal.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                        store.movePinned(id: id, before: goal.id)
                        return true
                    }
            }
        }
    }
}

private struct PinnedGoalRow: View {
    @EnvironmentObject private var store: Store
    let goal: GoalItem

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if !goal.isDone { Haptics.success() }
                store.toggleGoal(goal)
            } label: {
                CheckCircle(isDone: goal.isDone)
            }
            .buttonStyle(.plain)

            HorizonChip(horizon: goal.horizon)

            HashtagLabel(text: goal.title, isDone: goal.isDone)
                .font(.callout)

            Spacer()

            Button { store.togglePinGoal(goal) } label: {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("상단 고정 해제")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
