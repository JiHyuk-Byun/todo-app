import SwiftUI

/// 별도 창으로 열리는 스케줄러.
/// 왼쪽: 날짜 선택(캘린더) + 그 날의 todo 편집.
/// 오른쪽: 반복 일정 규칙 관리.
struct SchedulerView: View {
    @EnvironmentObject private var store: Store
    @State private var selectedDay = Date()

    var body: some View {
        HSplitView {
            dayPlanner
                .frame(minWidth: 360)
            RecurringPanel()
                .frame(minWidth: 300)
        }
        .frame(minWidth: 720, minHeight: 460)
    }

    private var dayPlanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "날짜",
                selection: $selectedDay,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            Divider()

            DayTodoList(day: selectedDay)
        }
        .padding(16)
    }
}

/// 선택한 날짜의 todo 목록 편집 영역.
private struct DayTodoList: View {
    @EnvironmentObject private var store: Store
    let day: Date

    @State private var newTitle = ""

    private var todos: [TodoItem] { store.todos(on: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.headline)

            HStack {
                TextField("이 날에 할 일 추가…", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("추가", action: add)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if todos.isEmpty {
                Text("등록된 할 일이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                List {
                    ForEach(todos) { todo in
                        EditableTodoRow(todo: todo)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func add() {
        store.addTodo(title: newTitle, on: day)
        newTitle = ""
    }
}

/// 제목을 인라인으로 수정/삭제할 수 있는 한 줄.
private struct EditableTodoRow: View {
    @EnvironmentObject private var store: Store
    @State var todo: TodoItem

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(todo)
                todo.isDone.toggle()
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            TextField("제목", text: $todo.title)
                .textFieldStyle(.plain)
                .strikethrough(todo.isDone, color: .secondary)
                .onSubmit { store.update(todo) }

            if todo.recurringID != nil {
                Image(systemName: "repeat")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button(role: .destructive) {
                store.delete(todo)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Recurring panel

private struct RecurringPanel: View {
    @EnvironmentObject private var store: Store
    @State private var showingNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("반복 일정")
                    .font(.headline)
                Spacer()
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.bottom, 4)

            if store.rules.isEmpty {
                Text("반복 일정이 없습니다.\n매일/매주 반복되는 할 일을 등록하면\n해당 날짜에 자동으로 추가됩니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.rules) { rule in
                        RuleRow(rule: rule)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .sheet(isPresented: $showingNew) {
            RuleEditor()
        }
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var store: Store
    let rule: RecurringRule

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "repeat")
                .foregroundStyle(rule.isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .foregroundStyle(rule.isActive ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isActive },
                set: { var r = rule; r.isActive = $0; store.update(r) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            Button(role: .destructive) {
                store.deleteRule(rule)
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        switch rule.frequency {
        case .daily:
            return "매일"
        case .weekly:
            let names = ["일", "월", "화", "수", "목", "금", "토"]
            let days = rule.weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ")
            return days.isEmpty ? "매주" : "매주 \(days)"
        }
    }
}

/// 새 반복 일정 만들기 시트.
private struct RuleEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var frequency: Frequency = .daily
    @State private var weekdays: Set<Int> = []

    private let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 반복 일정")
                .font(.headline)

            TextField("할 일 제목", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("반복", selection: $frequency) {
                ForEach(Frequency.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)

            if frequency == .weekly {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { wd in
                        let on = weekdays.contains(wd)
                        Button(weekdayNames[wd - 1]) {
                            if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                        }
                        .buttonStyle(.bordered)
                        .tint(on ? .accentColor : .gray)
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                Button("추가") {
                    let rule = RecurringRule(
                        title: title.trimmingCharacters(in: .whitespaces),
                        frequency: frequency,
                        weekdays: frequency == .weekly ? weekdays : [],
                        startDay: Date()
                    )
                    store.addRule(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                          || (frequency == .weekly && weekdays.isEmpty))
            }
        }
        .padding(20)
        .frame(width: 360, height: 260)
    }
}
