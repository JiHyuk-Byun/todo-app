import AppKit
import SwiftUI

/// 메뉴바에 표시되는 라벨: 커스텀 아이콘 + "완료/전체" 카운트.
/// store 를 관찰하므로 할 일이 바뀌면 카운트가 실시간으로 갱신된다.
struct MenuBarLabel: View {
    @ObservedObject var store: Store

    var body: some View {
        let counts = store.todayCounts()
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image)
            if counts.total > 0 {
                Text("\(counts.done)/\(counts.total)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
    }
}

/// 메뉴바에 표시할 커스텀 아이콘을 코드로 그린다.
/// (SF Symbol이 이 환경에서 0폭으로 렌더되는 문제가 있어 직접 그린다.)
/// template 이미지라서 라이트/다크 메뉴바에 자동으로 흑/백 적응한다.
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // 둥근 사각형 테두리 (체크리스트 박스 느낌)
            let boxRect = CGRect(x: 1.5, y: 1.5, width: 15, height: 15)
            let box = NSBezierPath(roundedRect: boxRect, xRadius: 4.5, yRadius: 4.5)
            box.lineWidth = 1.6
            NSColor.black.setStroke()
            box.stroke()

            // 굵은 체크마크
            let check = NSBezierPath()
            check.move(to: CGPoint(x: 5.0, y: 9.2))
            check.line(to: CGPoint(x: 8.0, y: 6.2))
            check.line(to: CGPoint(x: 13.2, y: 12.4))
            check.lineWidth = 2.0
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.black.setStroke()
            check.stroke()

            _ = ctx
            return true
        }
        img.isTemplate = true   // 메뉴바 명암에 자동 적응
        return img
    }()
}
