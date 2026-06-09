import SwiftUI

/// 통계 대시보드: 스트릭 · 요약 지표 · 배지.
struct StatsView: View {
    @EnvironmentObject private var store: Store

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
            }
            .padding(20)
        }
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
