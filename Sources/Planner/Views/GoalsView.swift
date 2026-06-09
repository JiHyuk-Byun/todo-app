import SwiftUI

/// 기간(이번 주/달/올해/비전)을 하나의 섹션으로, 그 안에서 영성/전문성으로 나눠 편집한다.
/// 카테고리를 ForEach 중첩 없이 명시적으로 배치해 각 목표 ForEach가 Section의
/// 직접 자식이 되도록 → 드래그 정렬이 동작한다.
struct GoalsView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        List {
            ForEach(GoalHorizon.allCases) { horizon in
                Section {
                    categoryGroup(horizon, .spirituality)
                    categoryGroup(horizon, .professional)
                } header: {
                    GoalSectionHeader(horizon: horizon)
                }
            }
        }
        .listStyle(.inset)
        .animation(.snappy(duration: 0.2), value: store.data.goals)
    }

    @ViewBuilder
    private func categoryGroup(_ horizon: GoalHorizon, _ category: TodoCategory) -> some View {
        CategorySubheader(horizon: horizon, category: category)

        ForEach(store.goals(horizon, category: category)) { goal in
            EditableChecklistRow(
                title: goal.title,
                isDone: goal.isDone,
                pinned: goal.pinned,
                onTogglePin: { store.togglePinGoal(goal) },
                onToggle: { store.toggleGoal(goal) },
                onCommitTitle: { var g = goal; g.title = $0; store.updateGoal(g) },
                onDelete: { store.deleteGoal(goal) }
            )
            .padding(.leading, 10)
        }
        .onMove { store.moveGoals(horizon, category: category, from: $0, to: $1) }

        GoalAddRow(horizon: horizon, category: category)
            .id("goaladd-\(horizon.rawValue)-\(category.rawValue)")
    }
}

/// 기간 섹션 헤더 — 색 칩으로 기간 구분.
private struct GoalSectionHeader: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon

    var body: some View {
        let c = store.goalCounts(horizon)
        HStack(spacing: 8) {
            HorizonChip(horizon: horizon)
            Text(store.periodSubtitle(horizon))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if c.total > 0 {
                Text("\(c.done)/\(c.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

/// 섹션 안 영성/전문성 소제목.
private struct CategorySubheader: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon
    let category: TodoCategory

    var body: some View {
        let c = store.goalCounts(horizon, category: category)
        HStack(spacing: 6) {
            Image(systemName: category.systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(category.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if c.total > 0 {
                Text("\(c.done)/\(c.total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 6)
    }
}

/// 기간·분류별 목표 추가 입력 줄(독립 @State).
private struct GoalAddRow: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon
    let category: TodoCategory

    @State private var newGoal = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HashtagTextField(text: $newGoal,
                             placeholder: "\(category.label) 목표 추가…",
                             onSubmit: add)
        }
        .padding(.leading, 10)
    }

    private func add() {
        store.addGoal(title: newGoal, horizon: horizon, category: category)
        newGoal = ""
    }
}
