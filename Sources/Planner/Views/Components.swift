import SwiftUI

/// 완료 토글용 원형 체크 아이콘.
struct CheckCircle: View {
    let isDone: Bool
    @State private var burst = 0

    var body: some View {
        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isDone ? Color.accentColor : .secondary)
            .font(.system(size: 16))
            .frame(width: 18, height: 18)        // 고정 크기 → 심볼 교체/바운스가 레이아웃에 영향 X
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: isDone)
            .overlay(MiniConfetti(trigger: burst))
            .onChange(of: isDone) { _, now in if now { burst += 1 } }
    }
}

/// 할 일/목표 공용 행: 체크 + 인라인 편집(더블클릭) + 호버 시 삭제.
struct EditableChecklistRow: View {
    let title: String
    let isDone: Bool
    var recurring: Bool = false
    var deleteHelp: String = "삭제"
    var onToggle: () -> Void
    var onCommitTitle: (String) -> Void
    var onDelete: () -> Void

    @State private var draft: String = ""
    @State private var isEditing = false
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if !isDone { Haptics.success() }
                withAnimation(.snappy(duration: 0.2)) { onToggle() }
            } label: {
                CheckCircle(isDone: isDone)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("제목", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand(perform: cancel)
            } else {
                HashtagLabel(text: title, isDone: isDone)
                    .onTapGesture(count: 2, perform: beginEdit)
                Spacer(minLength: 4)
            }

            if recurring {
                Image(systemName: "repeat")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if hovering && !isEditing {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(deleteHelp)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onChange(of: focused) { _, now in
            if !now && isEditing { commit() }
        }
    }

    private func beginEdit() {
        draft = title
        isEditing = true
        focused = true
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != title { onCommitTitle(trimmed) }
    }

    private func cancel() {
        isEditing = false
        draft = title
    }
}

/// 인라인 빠른 추가 입력 줄.
struct QuickAddField: View {
    var placeholder: String
    var onAdd: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.secondary)
            HashtagTextField(text: $text, placeholder: placeholder, onSubmit: submit)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        text = ""
    }
}
