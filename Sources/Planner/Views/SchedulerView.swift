import SwiftUI
import AppKit

/// 별도 창으로 열리는 스케줄러. 상단에서 [일정 | 목표]를 전환한다.
struct SchedulerView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var ui = UIState.shared
    @State private var selectedDay = Date()

    // 본문(배너+탭+달력)이 필요로 하는 기본 높이.
    private let baseHeight: CGFloat = 540

    private var screenCap: CGFloat { (NSScreen.main?.visibleFrame.height ?? 1000) - 60 }

    /// 화면 안에서 고정목표가 차지할 수 있는 최대 높이.
    private var pinnedAllowed: CGFloat {
        max(120, screenCap - baseHeight)
    }

    /// 고정목표 내용 높이(라벨+행).
    private var pinnedContentHeight: CGFloat {
        let count = store.pinnedGoals().count
        return count > 0 ? CGFloat(count) * 30 + 30 : 0
    }

    /// 핀에 따라 커지는 창 최소 높이(화면 상한 내).
    /// 반복 펼침은 달력이 공간을 흡수하므로 창 높이에 영향 주지 않는다.
    private var dynamicMinHeight: CGFloat {
        min(baseHeight + min(pinnedContentHeight, pinnedAllowed), screenCap)
    }

    var body: some View {
        // 순서: 오늘의 말씀 → 고정 목표 → 탭 바 → 본문. (평평한 VStack이라 탭이 안 가려짐)
        VStack(spacing: 0) {
            VerseBanner { ui.schedulerTab = .verse }
            Divider()
            PinnedGoalsList(fixedMaxHeight: pinnedAllowed)
            topBar
            Divider()
            Group {
                switch ui.schedulerTab {
                case .schedule: schedulePane
                case .goals: GoalsView()
                case .verse: VerseView()
                case .stats: StatsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()   // 창이 짧아도 본문이 위(탭 바)로 겹쳐 그려지지 않게
        }
        // 핀이 늘면 창 최소 높이가 커지고, 창이 그에 맞춰 아래로 자동 확장된다.
        .frame(minWidth: 720, minHeight: dynamicMinHeight)
        .overlay(BadgeUnlockOverlay())
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $ui.schedulerTab) {
                ForEach(SchedulerTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)

            Spacer()

            Button {
                withAnimation(.snappy) { selectedDay = Date(); ui.schedulerTab = .schedule }
            } label: {
                Label("오늘", systemImage: "calendar.circle")
            }
            .keyboardShortcut("t", modifiers: .command)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    private var schedulePane: some View {
        HSplitView {
            // 왼쪽: 달력(남는 공간 채움) + (아래) 반복 일정(내용 높이)
            VStack(spacing: 0) {
                MonthCalendarView(selection: $selectedDay)
                    .padding(16)
                    .frame(maxHeight: .infinity)
                Divider()
                RecurringPanel()
            }
            .frame(minWidth: 400)
            .background(.regularMaterial)

            // 오른쪽: 선택한 날의 할 일
            DayTodoList(day: selectedDay)
                .frame(minWidth: 320)
        }
    }
}

// MARK: - Day todo list

private struct DayTodoList: View {
    @EnvironmentObject private var store: Store
    let day: Date

    @State private var selectedID: TodoItem.ID?
    @State private var confetti = 0

    private var todos: [TodoItem] { store.todos(on: day) }

    /// 날짜별로 빠른추가 입력칸을 구분(날짜 바뀌면 입력 중 텍스트 초기화).
    private var dayID: Int { Int(Calendar.current.startOfDay(for: day).timeIntervalSinceReferenceDate) }

    private var dayAllDone: Bool {
        let s = store.dayStatus(on: day)
        return s.total > 0 && s.done == s.total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            List(selection: $selectedID) {
                ForEach(TodoCategory.allCases) { category in
                    Section {
                        ForEach(store.todos(on: day, category: category)) { todo in
                            TodoEditRow(todo: todo).tag(todo.id)
                        }
                        .onMove { store.moveTodos(on: day, category: category, from: $0, to: $1) }

                        QuickAddField(placeholder: "\(category.label) 할 일 추가…") {
                            store.addTodo(title: $0, on: day, category: category)
                        }
                        .id("todoadd-\(category.rawValue)-\(dayID)")
                    } header: {
                        categoryHeader(category)
                    }
                }
            }
            .listStyle(.inset)
            .onDeleteCommand {
                if let id = selectedID, let t = todos.first(where: { $0.id == id }) {
                    store.delete(t)
                }
            }
            .animation(.snappy(duration: 0.2), value: todos)
            // 메모 미리보기를 입력 차단 없는 오버레이로 그린다(떠 있어도 행 드래그 가능).
            .overlayPreferenceValue(NotePreviewKey.self) { data in
                GeometryReader { proxy in
                    if let data {
                        let rect = proxy[data.bounds]
                        NotePreview(title: data.title, note: data.note)
                            .fixedSize()
                            .offset(x: max(8, rect.minX), y: rect.maxY + 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .padding(16)
        .overlay(ConfettiView(trigger: confetti))
        .onChange(of: dayAllDone) { _, done in
            if done { confetti += 1 }
        }
        .task(id: day) { store.ensureMaterialized(for: day) }
    }

    private var header: some View {
        let s = store.dayStatus(on: day)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.title3.bold())
                Spacer()
                if s.total > 0 {
                    Text("\(s.done) / \(s.total) 완료")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if s.total > 0 {
                ProgressView(value: Double(s.done), total: Double(max(s.total, 1)))
                    .animation(.snappy, value: s.done)
            }
        }
    }

    private func categoryHeader(_ category: TodoCategory) -> some View {
        let c = store.dayCategoryCounts(on: day, category: category)
        return HStack(spacing: 6) {
            Label(category.label, systemImage: category.systemImage)
                .font(.headline)
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

/// 날짜별 할 일 한 줄: 공용 편집 행 + 메모 + swipe/contextMenu.
private struct TodoEditRow: View {
    @EnvironmentObject private var store: Store
    let todo: TodoItem
    @State private var showNotes = false
    @State private var hoveringRow = false
    @State private var previewArmed = false   // 잠깐 머문 뒤에만 미리보기(드래그로 잡을 땐 안 뜸)
    @State private var dragging = false        // 드래그 중엔 미리보기 억제

    private var isRecurring: Bool { todo.recurringID != nil }

    /// 메모가 있고, 편집 중/드래그 중이 아니며, 잠깐 머물렀을 때만 미리보기 표시.
    private var previewActive: Bool {
        previewArmed && hoveringRow && !dragging && !todo.notes.isEmpty && !showNotes
    }

    /// 호버 후 잠깐(0.45s) 머물면 미리보기를 켠다. 드래그로 바로 잡으면 안 뜬다.
    private func armPreview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if hoveringRow && !dragging && !showNotes { previewArmed = true }
        }
    }

    var body: some View {
        EditableChecklistRow(
            title: todo.title,
            isDone: todo.isDone,
            recurring: isRecurring,
            deleteHelp: isRecurring ? "이 날 건너뛰기" : "삭제",
            hasNote: !todo.notes.isEmpty,
            onToggleNote: { showNotes.toggle() },
            onToggle: { store.toggle(todo) },
            onCommitTitle: { var t = todo; t.title = $0; store.update(t) },
            onDelete: { store.delete(todo) }   // delete()가 반복 항목은 skip으로 라우팅
        )
        .onHover { hovering in
            hoveringRow = hovering
            if hovering {
                armPreview()
            } else {
                previewArmed = false
                dragging = false
            }
        }
        .onDrag {
            dragging = true        // 드래그 시작 → 미리보기 숨김(오버레이는 입력을 막지 않음)
            previewArmed = false
            return NSItemProvider(object: todo.id.uuidString as NSString)
        }
        // 미리보기는 입력을 가로채지 않는 오버레이로 띄운다(컨테이너에서 그림) → 떠 있어도 드래그 가능.
        .anchorPreference(key: NotePreviewKey.self, value: .bounds) { anchor in
            previewActive
                ? NotePreviewData(id: todo.id, title: todo.title, note: todo.notes, bounds: anchor)
                : nil
        }
        .popover(isPresented: $showNotes, arrowEdge: .trailing) {
            NoteEditor(title: todo.title, text: notesBinding)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(todo) } label: {
                Label(isRecurring ? "건너뛰기" : "삭제",
                      systemImage: isRecurring ? "calendar.badge.minus" : "trash")
            }
            Button { store.toggle(todo) } label: {
                Label(todo.isDone ? "미완료" : "완료", systemImage: "checkmark")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            Button(todo.isDone ? "미완료로 표시" : "완료로 표시") { store.toggle(todo) }
            Button("메모") { showNotes = true }
            Divider()
            if isRecurring {
                Button("이 날 건너뛰기", role: .destructive) { store.skipOccurrence(todo) }
            } else {
                Button("삭제", role: .destructive) { store.delete(todo) }
            }
        }
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { todo.notes },
            set: { var t = todo; t.notes = $0; store.update(t) }
        )
    }
}

/// 마우스 올렸을 때 뜨는 메모 미리보기 카드.
private struct NotePreview: View {
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "note.text").foregroundStyle(Color.accentColor)
                Text(title.isEmpty ? "메모" : title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(note)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }
}

/// 메모 미리보기 오버레이용 데이터(행 위치 anchor 포함).
private struct NotePreviewData: Equatable {
    let id: UUID
    let title: String
    let note: String
    let bounds: Anchor<CGRect>
}

private struct NotePreviewKey: PreferenceKey {
    static let defaultValue: NotePreviewData? = nil
    static func reduce(value: inout NotePreviewData?, nextValue: () -> NotePreviewData?) {
        if let next = nextValue() { value = next }
    }
}

/// 메모 작성 팝오버. 타이핑 중엔 로컬 상태만 쓰고(한글 IME 보호), 닫을 때 저장한다.
private struct NoteEditor: View {
    let title: String
    @Binding var text: String
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.isEmpty ? "메모" : title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $draft)
                .font(.body)
                .frame(height: 160)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                .focused($focused)
            Text("닫으면 저장됩니다")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 300)
        .padding(14)
        .onAppear { draft = text; focused = true }
        .onDisappear { text = draft }
    }
}

// MARK: - Recurring panel

private struct RecurringPanel: View {
    @EnvironmentObject private var store: Store
    @State private var showingNew = false
    @State private var editingRule: RecurringRule?
    @AppStorage("recurringExpanded") private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("반복 일정").font(.title3.bold())
                        if !store.rules.isEmpty {
                            Text("\(store.rules.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
                Button { showingNew = true } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("새 반복 일정")
            }

            if expanded {
                if store.rules.isEmpty {
                    emptyState
                } else {
                    // 자연 높이 행. 많으면 내부 스크롤(최대 300). 달력이 나머지 공간을 채운다.
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(store.rules.enumerated()), id: \.element.id) { idx, rule in
                                RuleRow(rule: rule) { editingRule = rule }
                                if idx < store.rules.count - 1 { Divider() }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .padding(16)
        .sheet(isPresented: $showingNew) { RuleEditor() }
        .sheet(item: $editingRule) { rule in RuleEditor(existing: rule) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("반복 일정이 없습니다")
                .foregroundStyle(.secondary)
            Text("매일/매주 반복되는 할 일을 등록하면\n해당 날짜에 자동으로 추가됩니다")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var store: Store
    let rule: RecurringRule
    var onEdit: () -> Void

    @State private var hovering = false
    @State private var confirmingDelete = false

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
                if rule.isActive, let next = rule.nextOccurrence() {
                    Text("다음: \(next.formatted(.dateTime.month().day().weekday()))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isActive },
                set: { var r = rule; r.isActive = $0; store.update(r) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            if hovering {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2, perform: onEdit)
        .confirmationDialog("이 반복 일정을 삭제할까요?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { store.deleteRule(rule) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("아직 완료하지 않은 자동 생성 항목도 함께 삭제됩니다.")
        }
    }

    private var subtitle: String {
        var base: String
        switch rule.frequency {
        case .daily:
            base = "매일"
        case .weekly:
            let names = Calendar.current.shortWeekdaySymbols
            let days = rule.weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ")
            base = days.isEmpty ? "매주" : "매주 \(days)"
        }
        if let end = rule.endDay {
            base += " · ~\(end.formatted(.dateTime.month().day()))까지"
        }
        return base
    }
}

// MARK: - Rule editor (create + edit)

private struct RuleEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    var existing: RecurringRule?

    @State private var title = ""
    @State private var frequency: Frequency = .daily
    @State private var weekdays: Set<Int> = []
    @State private var startDay = Date()
    @State private var hasEndDay = false
    @State private var endDay = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var category: TodoCategory = .spirituality

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("할 일") {
                    TextField("제목", text: $title)
                    Picker("분류", selection: $category) {
                        ForEach(TodoCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("반복") {
                    Picker("주기", selection: $frequency) {
                        ForEach(Frequency.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if frequency == .weekly {
                        weekdayPicker
                    }
                }
                Section("기간") {
                    DatePicker("시작일", selection: $startDay, displayedComponents: .date)
                    Toggle("종료일 설정", isOn: $hasEndDay)
                    if hasEndDay {
                        DatePicker("종료일", selection: $endDay,
                                   in: startDay..., displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "추가" : "저장") { saveRule() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(12)
        }
        .frame(width: 400, height: 440)
        .onAppear(perform: populate)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { wd in
                let on = weekdays.contains(wd)
                Button(cal.shortWeekdaySymbols[wd - 1]) {
                    if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                }
                .buttonStyle(.bordered)
                .tint(on ? .accentColor : .gray)
            }
        }
    }

    private var orderedWeekdays: [Int] {
        let first = cal.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && (frequency != .weekly || !weekdays.isEmpty)
    }

    private func populate() {
        guard let r = existing else { return }
        title = r.title
        frequency = r.frequency
        weekdays = r.weekdays
        startDay = r.startDay
        if let e = r.endDay { hasEndDay = true; endDay = e }
        category = r.category
    }

    private func saveRule() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let resolvedEnd = hasEndDay ? endDay : nil
        if var r = existing {
            r.title = trimmed
            r.frequency = frequency
            r.weekdays = frequency == .weekly ? weekdays : []
            r.startDay = startDay
            r.endDay = resolvedEnd
            r.category = category
            store.update(r)
        } else {
            store.addRule(RecurringRule(
                title: trimmed,
                frequency: frequency,
                weekdays: frequency == .weekly ? weekdays : [],
                startDay: startDay,
                endDay: resolvedEnd,
                category: category
            ))
        }
        dismiss()
    }
}
