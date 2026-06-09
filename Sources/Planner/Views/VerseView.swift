import SwiftUI

// MARK: - 최상단 "오늘의 말씀" 배너

struct VerseBanner: View {
    @EnvironmentObject private var store: Store
    var onOpen: () -> Void

    var body: some View {
        let v = store.todayVerse()
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("오늘의 말씀")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let v, !v.reference.isEmpty {
                        Text(v.reference)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let v, v.credits > 0 {
                        Label("\(v.credits)", systemImage: "checkmark.seal.fill")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }

                if let v, !v.text.isEmpty {
                    Text(v.text)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("탭하여 오늘 말씀 입력")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 말씀 탭 (등록 + 암송)

struct VerseView: View {
    @EnvironmentObject private var store: Store

    @State private var attempt = ""
    @State private var lastResult: Bool? = nil   // nil=미제출, true=정답, false=오답
    @State private var revealed = false          // 제출 후 원문 공개
    @State private var peeking = false           // 엿보기
    @State private var editing = false           // 등록/수정 폼
    @State private var draftText = ""
    @State private var draftRef = ""
    @State private var confetti = 0

    private var verse: Verse? { store.todayVerse() }
    private var showEditor: Bool { verse == nil || editing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if showEditor {
                    editorForm
                } else if let v = verse {
                    reciteView(v)
                }

                historySection
            }
            .padding(20)
        }
        .overlay(ConfettiView(trigger: confetti))
    }

    // MARK: 말씀 히스토리

    @ViewBuilder private var historySection: some View {
        let past = store.pastVerses()
        if !past.isEmpty {
            Divider().padding(.vertical, 4)
            HStack {
                Label("말씀 히스토리", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Text("\(past.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(past) { v in
                    VerseHistoryRow(verse: v)
                    if v.id != past.last?.id { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
        }
    }

    // MARK: 등록/수정 폼

    private var editorForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verse == nil ? "오늘의 말씀 등록" : "말씀 수정")
                .font(.title3.bold())

            TextField("출처 (예: 요한복음 3:16)", text: $draftRef)
                .textFieldStyle(.roundedBorder)

            Text("원문").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draftText)
                .font(.body)
                .frame(minHeight: 140)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            HStack {
                if verse != nil {
                    Button("취소") { editing = false }
                }
                Spacer()
                Button(verse == nil ? "등록" : "저장") {
                    store.setVerse(text: draftText, reference: draftRef, on: Date())
                    editing = false
                    resetAttempt()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: 암송

    private func reciteView(_ v: Verse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.reference.isEmpty ? "오늘의 말씀" : v.reference)
                        .font(.title3.bold())
                    Text("credit \(v.credits) · 시도 \(v.attempts)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let shown = peeking || revealed
                Button(shown ? "가리기" : "엿보기") {
                    if shown { peeking = false; revealed = false }
                    else { peeking = true }
                }
                Button("말씀 수정") { startEdit(v) }
            }

            // 원문: 엿보기 또는 제출 후에만 표시
            if peeking || revealed {
                Text(v.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            } else {
                Text("원문은 숨겨져 있어요. 외워서 입력해 보세요.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            Text("암송 입력").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $attempt)
                .font(.body)
                .frame(minHeight: 140)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            HStack(spacing: 12) {
                Button("제출", action: submit)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(attempt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let r = lastResult {
                    Label(r ? "정답! credit +1" : "원문과 달라요. 다시!",
                          systemImage: r ? "checkmark.seal.fill" : "xmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(r ? .green : .red)
                }
                Spacer()
                if lastResult != nil {
                    Button("다시 암송") { resetAttempt() }
                }
            }

            Text("⌘↩ 으로 제출")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: 동작

    private func submit() {
        let ok = store.recite(attempt, on: Date())
        lastResult = ok
        revealed = true
        if ok {
            Haptics.success()
            confetti += 1
            attempt = ""        // 정답이면 입력 내용 비우기
        }
    }

    private func resetAttempt() {
        attempt = ""
        lastResult = nil
        revealed = false
        peeking = false
    }

    private func startEdit(_ v: Verse) {
        draftText = v.text
        draftRef = v.reference
        editing = true
    }
}

/// 히스토리 한 줄: 날짜 + 출처 + credit + 본문(접기/펼치기).
private struct VerseHistoryRow: View {
    let verse: Verse
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Text(verse.day.formatted(.dateTime.month().day().weekday()))
                        .font(.callout.weight(.medium))
                    if !verse.reference.isEmpty {
                        Text(verse.reference)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if verse.credits > 0 {
                        Label("\(verse.credits)", systemImage: "checkmark.seal.fill")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(verse.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
