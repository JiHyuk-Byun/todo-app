import AppKit

// Planner 앱 아이콘 생성기: 보라 그라데이션 둥근 사각형 + 흰 체크마크를
// 각 사이즈로 직접 렌더해 AppIcon.iconset 에 저장한다.

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // 둥근 사각형(스퀴클 근사) — 약간의 여백을 둔다.
    let margin = size * 0.085
    let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let body = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.60, green: 0.40, blue: 0.98, alpha: 1).cgColor,
        NSColor(srgbRed: 0.40, green: 0.20, blue: 0.86, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // 흰 체크마크 (좌표 원점 좌하단, y는 위로 증가).
    let cm = CGMutablePath()
    cm.move(to: CGPoint(x: size * 0.32, y: size * 0.50))
    cm.addLine(to: CGPoint(x: size * 0.44, y: size * 0.37))
    cm.addLine(to: CGPoint(x: size * 0.70, y: size * 0.64))
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(size * 0.072)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(cm)
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let outDir = "icon/AppIcon.iconset"
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (파일명, 픽셀크기)
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, px) in specs {
    let data = render(px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("✓ \(name) (\(px)px)")
}
print("done")
