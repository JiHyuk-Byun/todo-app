import SwiftUI

/// 상단 메뉴바 아이콘을 클릭하면 나오는 드롭다운.
/// 오늘의 todo + 접이식 목표 섹션을 보여준다.
struct MenuBarView: View {
    @EnvironmentObject private var store: Store

    @State private var expanded: Set<GoalHorizon> = []
    // 항상 현재 날짜를 반영(자정 경과 후에도 "오늘"로 갱신). 프레임 고정용 @State가 아니다.
    // Store가 60초마다, 그리고 드롭다운 열 때 refreshNow()로 objectWillChange를 보내 재평가된다.
    private var now: Date { Date() }
    @State private var measuredHeight: CGFloat = 220   // 실시간 측정값(프레임엔 직접 안 씀)
    @State private var contentHeight: CGFloat = 220    // 실제 적용 높이(구조 변경 시에만 갱신)
    @State private var initializedHeight = false
    @State private var confettiTrigger = 0

    private var todayAllDone: Bool {
        let s = store.dayStatus(on: now)
        return s.total > 0 && s.done == s.total
    }

    /// 행 개수·펼침 상태가 바뀔 때만 달라지는 값. 체크(완료 토글)로는 안 바뀐다.
    private var structureID: Int {
        var n = store.todos(on: now).count + GoalHorizon.allCases.count
        for h in expanded { n = n &* 31 &+ store.goals(h).count }
        n = n &* 7 &+ expanded.count
        return n
    }

    private var todos: [TodoItem] { store.todaysTodos() }
    private var doneCount: Int { todos.filter(\.isDone).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VerseBanner {
                UIState.shared.schedulerTab = .verse
                AppDelegate.shared?.openSchedulerFromMenu()
            }
            Divider()
            PinnedGoalsList(fixedMaxHeight: 220)
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(TodoCategory.allCases) { category in
                        TodoCategoryGroup(category: category, day: now)
                    }

                    Divider().padding(.vertical, 4)

                    goalsSection
                }
                .padding(.vertical, 4)
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                })
            }
            // 팝오버 안에서 ScrollView는 이상적 높이를 0으로 보고하므로 측정해서 높이를 준다.
            // 단, 체크 토글 때 재측정으로 팝오버가 들썩이지 않도록, 높이는 "구조(행 개수/펼침)가
            // 바뀔 때"만 측정값으로 갱신한다. 토글은 구조를 안 바꾸므로 높이 고정.
            .frame(height: min(contentHeight, 520))
            .animation(nil, value: contentHeight)
            .onPreferenceChange(ContentHeightKey.self) { h in
                measuredHeight = h
                if !initializedHeight {
                    initializedHeight = true
                    contentHeight = h.rounded()
                }
            }
            .onChange(of: structureID) { _, _ in
                contentHeight = measuredHeight.rounded()
            }

            Divider()
            footer
        }
        .frame(width: 360)
        .overlay(ConfettiView(trigger: confettiTrigger))
        .overlay(BadgeUnlockOverlay())
        .onChange(of: todayAllDone) { _, done in
            if done { confettiTrigger += 1 }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘 할 일")
                    .font(.headline)
                Text(now.formatted(.dateTime.year().month().day().weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StreakChip(days: store.todoStreak(), tint: .orange)
            StreakChip(days: store.verseStreak(), tint: .purple)
            if !todos.isEmpty {
                Text("\(doneCount)/\(todos.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("목표")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)

            ForEach(GoalHorizon.allCases) { horizon in
                GoalDisclosure(
                    horizon: horizon,
                    isExpanded: expanded.contains(horizon)
                ) { toggleExpand(horizon) }
            }
        }
    }

    private func toggleExpand(_ horizon: GoalHorizon) {
        withAnimation(.snappy(duration: 0.18)) {
            if expanded.contains(horizon) { expanded.remove(horizon) }
            else { expanded.insert(horizon) }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                AppDelegate.shared?.openSchedulerFromMenu()
            } label: {
                Label("스케줄러", systemImage: "calendar")
            }
            .buttonStyle(.plain)

            SettingsLink {
                Label("설정", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("종료", systemImage: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

}

/// 드롭다운의 카테고리(영성/전문성) 그룹: 소제목 + 항목 + 추가. 항상 표시된다.
private struct TodoCategoryGroup: View {
    @EnvironmentObject private var store: Store
    let category: TodoCategory
    let day: Date

    @State private var newTitle = ""

    var body: some View {
        let c = store.dayCategoryCounts(on: day, category: category)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: category.systemImage).font(.caption2)
                Text(category.label).font(.caption.bold())
                Spacer()
                if c.total > 0 {
                    Text("\(c.done)/\(c.total)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 1)

            ForEach(store.todos(on: day, category: category)) { todo in
                TodoRow(todo: todo)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)
                HashtagTextField(text: $newTitle,
                                 placeholder: "\(category.label) 할 일 추가…",
                                 onSubmit: add)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }

    private func add() {
        store.addTodo(title: newTitle, on: day, category: category)
        newTitle = ""
    }
}

/// 드롭다운 콘텐츠의 실제 높이 측정용.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 메뉴바 드롭다운 안의 한 줄: 체크박스 + 제목.
private struct TodoRow: View {
    @EnvironmentObject private var store: Store
    let todo: TodoItem

    var body: some View {
        Button {
            if !todo.isDone { Haptics.success() }
            store.toggle(todo)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                CheckCircle(isDone: todo.isDone)
                VStack(alignment: .leading, spacing: 2) {
                    HashtagLabel(text: todo.title, isDone: todo.isDone)
                    if !todo.notes.isEmpty {
                        Label(todo.notes, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if todo.recurringID != nil {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

/// 목표 기간 한 개의 접이식 섹션 (헤더 + 펼치면 항목/추가).
private struct GoalDisclosure: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        let c = store.goalCounts(horizon)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Image(systemName: horizon.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(horizon.label)
                    Spacer()
                    if c.total > 0 {
                        Text("\(c.done)/\(c.total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(TodoCategory.allCases) { category in
                    GoalCategoryGroup(horizon: horizon, category: category)
                }
            }
        }
    }
}

/// 드롭다운 목표 섹션 안의 영성/전문성 하위그룹(소제목 + 항목 + 추가).
private struct GoalCategoryGroup: View {
    @EnvironmentObject private var store: Store
    let horizon: GoalHorizon
    let category: TodoCategory

    @State private var newGoal = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 9))
                Text(category.label)
                    .font(.caption2.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.tertiary)
            .padding(.leading, 32)
            .padding(.trailing, 14)
            .padding(.top, 3)

            ForEach(store.goals(horizon, category: category)) { goal in
                GoalRow(goal: goal)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
                HashtagTextField(text: $newGoal,
                                 placeholder: "\(category.label) 목표 추가…",
                                 onSubmit: addGoal)
            }
            .padding(.leading, 44)
            .padding(.trailing, 14)
            .padding(.vertical, 3)
        }
    }

    private func addGoal() {
        store.addGoal(title: newGoal, horizon: horizon, category: category)
        newGoal = ""
    }
}

/// 드롭다운 안의 목표 한 줄(들여쓰기 + 체크).
private struct GoalRow: View {
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

            HashtagLabel(text: goal.title, isDone: goal.isDone)
                .font(.callout)

            Spacer()

            Button { store.togglePinGoal(goal) } label: {
                Image(systemName: goal.pinned ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(goal.pinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(goal.pinned ? "상단 고정 해제" : "상단에 고정")
        }
        .padding(.leading, 32)
        .padding(.trailing, 14)
        .padding(.vertical, 4)
    }
}
