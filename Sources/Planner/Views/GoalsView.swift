import SwiftUI

/// 주간/월간/1년/비전 목표를 기간 → 영성/전문성 하위그룹의 체크리스트로 편집한다.
struct GoalsView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        List {
            ForEach(GoalHorizon.allCases) { horizon in
                Section {
                    ForEach(TodoCategory.allCases) { category in
                        CategorySubheader(horizon: horizon, category: category)

                        ForEach(store.goals(horizon, category: category)) { goal in
                            EditableChecklistRow(
                                title: goal.title,
                                isDone: goal.isDone,
                                onToggle: { store.toggleGoal(goal) },
                                onCommitTitle: { var g = goal; g.title = $0; store.updateGoal(g) },
                                onDelete: { store.deleteGoal(goal) }
                            )
                            .padding(.leading, 12)
                        }
                        .onMove { store.moveGoals(horizon, category: category, from: $0, to: $1) }

                        // add 입력란은 (horizon,category)별 독립 @State를 위해 별도 뷰 + 명시적 id.
                        GoalAddRow(horizon: horizon, category: category)
                            .id("goaladd-\(horizon.rawValue)-\(category.rawValue)")
                    }
                } header: {
                    GoalSectionHeader(horizon: horizon)
                }
            }
        }
        .listStyle(.inset)
        .animation(.snappy(duration: 0.2), value: store.data.goals)
    }
}

private struct GoalSectionHeader: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon

    var body: some View {
        let c = store.goalCounts(horizon)
        HStack(spacing: 8) {
            Label(horizon.label, systemImage: horizon.systemImage)
                .font(.headline)
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
        .padding(.vertical, 2)
    }
}

/// 기간 섹션 내부의 영성/전문성 소제목.
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
        .padding(.top, 4)
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
        .padding(.leading, 12)
    }

    private func add() {
        store.addGoal(title: newGoal, horizon: horizon, category: category)
        newGoal = ""
    }
}
