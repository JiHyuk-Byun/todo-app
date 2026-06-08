import SwiftUI

/// 상단 메뉴바 아이콘을 클릭하면 나오는 드롭다운.
/// 오늘의 todo를 보여주고 체크박스로 완료 토글, 빠른 추가가 가능하다.
struct MenuBarView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openWindow) private var openWindow

    @State private var newTitle: String = ""
    @State private var now = Date()

    private var todos: [TodoItem] { store.todaysTodos() }

    private var doneCount: Int { todos.filter(\.isDone).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if todos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(todos) { todo in
                            TodoRow(todo: todo)
                        }
                    }
                    .padding(.vertical, 6)
                }
                // MenuBarExtra(.window) 안에서 ScrollView가 0높이로 접히는 문제를
                // 막기 위해 내용 개수에 맞춰 명시적 높이를 준다.
                .frame(height: min(CGFloat(todos.count) * 34 + 12, 320))
            }

            Divider()

            quickAdd

            Divider()

            footer
        }
        .frame(width: 320)
    }

    // MARK: - Sections

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
            if !todos.isEmpty {
                Text("\(doneCount)/\(todos.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("오늘 할 일이 없어요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var quickAdd: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.secondary)
            TextField("할 일 추가…", text: $newTitle)
                .textFieldStyle(.plain)
                .onSubmit(addTodo)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "scheduler")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("스케줄러", systemImage: "calendar")
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

    private func addTodo() {
        store.addTodo(title: newTitle, on: Date())
        newTitle = ""
    }
}

/// 메뉴바 드롭다운 안의 한 줄: 체크박스 + 제목.
private struct TodoRow: View {
    @EnvironmentObject private var store: Store
    let todo: TodoItem

    var body: some View {
        Button {
            store.toggle(todo)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? Color.accentColor : .secondary)
                    .font(.system(size: 16))
                Text(todo.title)
                    .strikethrough(todo.isDone, color: .secondary)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
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
