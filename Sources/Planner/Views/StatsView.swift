import SwiftUI

/// 통계 대시보드: 스트릭 · 요약 지표 · 배지.
struct StatsView: View {
    @EnvironmentObject private var store: Store

    @State private var archiveKind: ArchiveKind = .verse
    @State private var expandedVerses: Set<UUID> = []

    private let summaryCols = [GridItem(.flexible()), GridItem(.flexible())]
    private let badgeCols = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    StreakCard(title: "할 일 연속", days: store.todoStreak(), tint: .orange)
                    StreakCard(title: "말씀 연속", days: store.verseStreak(), tint: .purple)
                }

                LazyVGrid(columns: summaryCols, spacing: 12) {
                    StatCard(icon: "chart.bar.fill", tint: .blue,
                             value: "\(Int(store.weeklyCompletionRate() * 100))%", title: "주간 완료율")
                    StatCard(icon: "checkmark.circle.fill", tint: .green,
                             value: "\(store.completedTodoCount())", title: "누적 완료")
                    StatCard(icon: "sparkles", tint: .pink,
                             value: "\(store.totalCredits())", title: "누적 credit")
                    StatCard(icon: "book.fill", tint: .indigo,
                             value: "\(store.versesRecitedCount())", title: "외운 말씀")
                }

                Text("배지")
                    .font(.headline)
                    .padding(.top, 4)
                LazyVGrid(columns: badgeCols, spacing: 12) {
                    ForEach(Achievements.all) { badge in
                        BadgeCell(badge: badge, unlocked: badge.isUnlocked(store))
                    }
                }

                archiveSection
            }
            .padding(20)
        }
    }

    // MARK: - 완료 기록 아카이브

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("기록")
                .font(.headline)
                .padding(.top, 8)

            Picker("", selection: $archiveKind) {
                ForEach(ArchiveKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch archiveKind {
            case .verse: verseArchive
            case .todo:  todoArchive
            case .goal:  goalArchive
            }
        }
    }

    @ViewBuilder private var verseArchive: some View {
        let verses = store.completedVerses()
        if verses.isEmpty {
            ArchiveEmpty(text: "아직 외운 말씀이 없어요.")
        } else {
            VStack(spacing: 0) {
                ForEach(verses) { v in
                    VerseArchiveRow(
                        verse: v,
                        expanded: expandedVerses.contains(v.id)
                    ) {
                        if expandedVerses.contains(v.id) { expandedVerses.remove(v.id) }
                        else { expandedVerses.insert(v.id) }
                    }
                    if v.id != verses.last?.id { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.35)))
        }
    }

    @ViewBuilder private var todoArchive: some View {
        let groups = store.completedTodosByDay()
        if groups.isEmpty {
            ArchiveEmpty(text: "아직 완료한 할 일이 없어요.")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.day.formatted(.dateTime.year().month().day().weekday()))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            ForEach(group.items) { todo in
                                DoneItemRow(title: todo.title, category: todo.category)
                                if todo.id != group.items.last?.id { Divider() }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.35)))
                    }
                }
            }
        }
    }

    @ViewBuilder private var goalArchive: some View {
        let groups = store.archivedGoalsByPeriod()
        if groups.isEmpty {
            ArchiveEmpty(text: "아직 지난 기간 목표가 없어요.")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            HorizonChip(horizon: group.horizon)
                            if group.horizon != .vision {
                                Text(periodLabel(group.periodKey))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            let done = group.items.filter(\.isDone).count
                            Text("\(done)/\(group.items.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        VStack(spacing: 0) {
                            ForEach(group.items) { goal in
                                DoneItemRow(title: goal.title, category: goal.category, done: goal.isDone)
                                if goal.id != group.items.last?.id { Divider() }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.35)))
                    }
                }
            }
        }
    }
}

/// 통계 아카이브 종류.
private enum ArchiveKind: String, CaseIterable, Identifiable {
    case verse, todo, goal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .verse: return "말씀"
        case .todo:  return "할 일"
        case .goal:  return "목표"
        }
    }
}

/// periodKey("2026-06" 등) → 사람이 읽는 기간 라벨.
private func periodLabel(_ key: String) -> String {
    if key == "vision" { return "비전" }
    if let r = key.range(of: "-W") {
        let year = String(key[..<r.lowerBound])
        let week = Int(key[r.upperBound...]) ?? 0
        return "\(year)년 \(week)주차"
    }
    let parts = key.split(separator: "-")
    if parts.count == 2, let m = Int(parts[1]) {
        return "\(parts[0])년 \(m)월"
    }
    return "\(key)년"
}

/// 영성/전문성 배지(아이콘+라벨).
private struct CategoryBadge: View {
    let category: TodoCategory
    private var tint: Color { category == .spirituality ? .purple : .blue }
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.systemImage)
            Text(category.label)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.15)))
    }
}

/// 완료한/미달성 할 일·목표 한 줄: 상태 아이콘 + 제목 + (미달성 태그) + 카테고리 배지.
private struct DoneItemRow: View {
    let title: String
    let category: TodoCategory
    var done: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
                .font(.callout)
            HashtagLabel(text: title, isDone: false)
                .opacity(done ? 1 : 0.6)
            Spacer(minLength: 6)
            if !done {
                Text("미달성")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            CategoryBadge(category: category)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

/// 외운 말씀 한 줄(탭하면 원문 펼침).
private struct VerseArchiveRow: View {
    let verse: Verse
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onToggle) {
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
                    Spacer(minLength: 6)
                    Label("\(verse.credits)", systemImage: "checkmark.seal.fill")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct ArchiveEmpty: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
    }
}

/// 작은 스트릭 칩(드롭다운 헤더 등). 0이면 표시 안 함.
struct StreakChip: View {
    let days: Int
    let tint: Color
    var body: some View {
        if days > 0 {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                Text("\(days)").monospacedDigit()
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
        }
    }
}

private struct StreakCard: View {
    let title: String
    let days: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(days > 0 ? tint : .secondary)
                Text("\(days)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("일").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(days > 0 ? 0.14 : 0.06)))
    }
}

private struct StatCard: View {
    let icon: String
    let tint: Color
    let value: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold().monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }
}

private struct BadgeCell: View {
    let badge: Badge
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: unlocked ? badge.systemImage : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(unlocked ? Color.accentColor : .secondary)
            }
            Text(badge.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(unlocked ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .help(badge.detail)
    }
}
