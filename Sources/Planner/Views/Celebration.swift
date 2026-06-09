import SwiftUI
import AppKit

/// 완료 시 햅틱 피드백.
enum Haptics {
    static func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

/// trigger 값이 바뀔 때마다 가운데에서 콘페티가 터진다. 클릭을 가로채지 않는다.
struct ConfettiView: View {
    var trigger: Int
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint]

    @State private var run = 0

    var body: some View {
        ZStack {
            if run > 0 {
                ForEach(0..<28, id: \.self) { i in
                    ConfettiPiece(index: i, run: run, color: colors[i % colors.count])
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in run += 1 }
    }
}

/// 체크박스 주변에서 터지는 작은 콘페티(개별 체크용).
/// 행 경계에 가리지 않도록 넉넉한 프레임 위에 그린다.
struct MiniConfetti: View {
    var trigger: Int
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    @State private var run = 0

    var body: some View {
        ZStack {
            if run > 0 {
                ForEach(0..<14, id: \.self) { i in
                    MiniPiece(index: i, run: run, color: colors[i % colors.count])
                }
            }
        }
        .frame(width: 80, height: 80)          // 큰 좌표 공간(중앙 기준 방사)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in run += 1 }
    }
}

private struct MiniPiece: View {
    let index: Int
    let run: Int
    let color: Color

    @State private var p: CGFloat = 0

    var body: some View {
        let angle = Double(index) / 14.0 * 2 * .pi
        let dist = CGFloat(26 + (index * 7) % 12)
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .offset(x: CGFloat(cos(angle)) * dist * p,
                    y: CGFloat(sin(angle)) * dist * p + 10 * p * p)
            .opacity(1 - Double(p))
            .scaleEffect(1 - 0.3 * p)
            .onChange(of: run) { _, _ in fire() }
            .onAppear { fire() }
    }

    private func fire() {
        p = 0
        withAnimation(.easeOut(duration: 0.7)) { p = 1 }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let run: Int
    let color: Color

    @State private var progress: CGFloat = 0

    var body: some View {
        let angle = Double(index) / 28.0 * 2 * .pi
        let spread = CGFloat(50 + (index * 53) % 70)
        let drift = CGFloat((index * 29) % 30) - 15

        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 6, height: 8)
            .rotationEffect(.degrees(Double(index * 40) + progress * 360))
            .offset(
                x: CGFloat(cos(angle)) * spread * progress + drift * progress,
                y: CGFloat(sin(angle)) * spread * progress + 120 * progress * progress - 30 * progress
            )
            .opacity(1 - Double(progress))
            .onChange(of: run) { _, _ in fire() }
            .onAppear { fire() }
    }

    private func fire() {
        progress = 0
        withAnimation(.easeOut(duration: 1.0)) { progress = 1 }
    }
}
