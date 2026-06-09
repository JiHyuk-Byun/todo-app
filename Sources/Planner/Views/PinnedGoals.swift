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

/// 상단에 고정된 목표 모음. List + .onMove로 네이티브 드래그(삽입 위치 표시) 통일.
struct PinnedGoalsBar: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let pinned = store.pinnedGoals()
        if !pinned.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Label("고정한 목표", systemImage: "pin.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)

                List {
                    ForEach(pinned) { goal in
                        PinnedGoalRow(goal: goal)
                            .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { store.movePinned(from: $0, to: $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(pinned.count) * 30 + 4)
            }
            .padding(.bottom, 4)
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
    }
}
