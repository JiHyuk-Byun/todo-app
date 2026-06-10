import SwiftUI
import AppKit

/// 해시태그 패턴: # 뒤에 글자/숫자/밑줄(공백·구두점 전까지).
let hashtagRegex = try! NSRegularExpression(pattern: "#[\\p{L}0-9_]+")

// MARK: - Per-keyword color

private let tagColors: [Color] = [
    .purple, .blue, .pink, .orange, .green, .teal, .indigo, .red, .mint, .brown, .cyan
]
private let tagNSColors: [NSColor] = [
    .systemPurple, .systemBlue, .systemPink, .systemOrange, .systemGreen,
    .systemTeal, .systemIndigo, .systemRed, .systemMint, .systemBrown, .systemCyan
]

/// 키워드 → 안정적 인덱스(같은 키워드는 항상 같은 색). FNV-1a 해시(런 간에도 안정적).
private func stableIndex(_ key: String, _ count: Int) -> Int {
    var h: UInt64 = 1469598103934665603
    for b in key.lowercased().utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
    return Int(h % UInt64(count))
}

func tagColor(_ key: String) -> Color { tagColors[stableIndex(key, tagColors.count)] }
func tagNSColor(_ key: String) -> NSColor { tagNSColors[stableIndex(key, tagNSColors.count)] }

// MARK: - Token model

private struct HashToken: Identifiable {
    let id = UUID()
    let text: String
    let isTag: Bool
    var key: String { isTag ? String(text.dropFirst()) : "" }
}

private func hashTokens(_ s: String) -> [HashToken] {
    let ns = s as NSString
    var toks: [HashToken] = []
    var loc = 0
    func appendPlain(_ str: String) {
        for w in str.split(separator: " ", omittingEmptySubsequences: true) {
            toks.append(HashToken(text: String(w), isTag: false))
        }
    }
    for m in hashtagRegex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        if m.range.location > loc {
            appendPlain(ns.substring(with: NSRange(location: loc, length: m.range.location - loc)))
        }
        toks.append(HashToken(text: ns.substring(with: m.range), isTag: true))
        loc = m.range.location + m.range.length
    }
    if loc < ns.length { appendPlain(ns.substring(from: loc)) }
    return toks
}

// MARK: - Display label (pills)

/// #해시태그를 키워드별 색상의 알약 배지로, 나머지는 일반 텍스트로 렌더(자동 줄바꿈).
struct HashtagLabel: View {
    let text: String
    var isDone: Bool = false

    var body: some View {
        WrapLayout(spacing: 4, lineSpacing: 3) {
            ForEach(hashTokens(text)) { tok in
                if tok.isTag {
                    Text(tok.text)
                        .fontWeight(.medium)
                        .foregroundStyle(isDone ? AnyShapeStyle(.secondary)
                                                : AnyShapeStyle(tagColor(tok.key)))
                        .strikethrough(isDone, color: .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(tagColor(tok.key).opacity(isDone ? 0.08 : 0.16))
                        )
                } else {
                    Text(tok.text)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .strikethrough(isDone, color: .secondary)
                }
            }
        }
    }
}

/// 간단한 좌->우, 넘치면 다음 줄로 흐르는 플로우 레이아웃.
struct WrapLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW {
                x = 0; y += lineH + lineSpacing; lineH = 0
            }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
            widest = max(widest, x - spacing)
        }
        let totalW = maxW.isFinite ? min(widest, maxW) : widest
        return CGSize(width: totalW, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX {
                x = bounds.minX; y += lineH + lineSpacing; lineH = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}

// MARK: - Pill text attachment

/// 입력 필드 안에서 #해시태그를 키워드 색상의 알약으로 그리는 텍스트 첨부 셀.
/// 첨부는 1글자(U+FFFC)라 백스페이스로 통째 삭제된다.
final class PillCell: NSTextAttachmentCell {
    let tagText: String
    let pillFont: NSFont
    private var color: NSColor { tagNSColor(String(tagText.dropFirst())) }

    init(tag: String, font: NSFont) {
        self.tagText = tag
        self.pillFont = font
        super.init()
    }
    required init(coder: NSCoder) { fatalError() }

    private var textAttrs: [NSAttributedString.Key: Any] {
        [.font: pillFont, .foregroundColor: color]
    }

    override func cellSize() -> NSSize {
        let s = (tagText as NSString).size(withAttributes: textAttrs)
        return NSSize(width: ceil(s.width) + 14, height: ceil(s.height) + 4)
    }

    override func cellBaselineOffset() -> NSPoint {
        NSPoint(x: 0, y: pillFont.descender - 2)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let rect = cellFrame.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        color.withAlphaComponent(0.18).setFill()
        path.fill()
        let size = (tagText as NSString).size(withAttributes: textAttrs)
        let pt = NSPoint(x: cellFrame.midX - size.width / 2, y: cellFrame.midY - size.height / 2)
        (tagText as NSString).draw(at: pt, withAttributes: textAttrs)
    }
}

/// 빈 값일 때 placeholder를 그리고, Enter는 줄바꿈 대신 제출하는 텍스트 뷰.
final class PillNSTextView: NSTextView {
    var placeholder: String = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        (placeholder as NSString).draw(
            at: NSPoint(x: textContainerInset.width + 2, y: textContainerInset.height),
            withAttributes: attrs)
    }
}

// MARK: - Live pill text field

/// 입력 중 `#키워드` + 스페이스를 누르면 그 자리에서 알약 배지로 바뀌는 단일 줄 입력 필드.
/// (NSTextView + 텍스트 첨부로 구현 — 첨부는 한 글자라 백스페이스로 통째 삭제됨.)
struct HashtagTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var onSubmit: () -> Void = {}

    func makeNSView(context: Context) -> PillNSTextView {
        let tv = PillNSTextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.isRichText = true
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textContainerInset = NSSize(width: 0, height: 3)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.placeholder = placeholder
        context.coordinator.textView = tv
        context.coordinator.render(text)
        return tv
    }

    func updateNSView(_ nsView: PillNSTextView, context: Context) {
        context.coordinator.parent = self
        nsView.placeholder = placeholder
        // 조합 중(marked text)엔 다시 그리지 않는다 — 한글 입력 깨짐 방지.
        if !nsView.hasMarkedText(), context.coordinator.modelString() != text {
            context.coordinator.render(text)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PillNSTextView, context: Context) -> CGSize? {
        let h = ceil(font.ascender - font.descender + font.leading) + 12
        return CGSize(width: proposal.width ?? 120, height: h)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HashtagTextField
        weak var textView: PillNSTextView?
        private var isMutating = false
        init(_ parent: HashtagTextField) { self.parent = parent }

        private var baseAttrs: [NSAttributedString.Key: Any] {
            [.font: parent.font, .foregroundColor: NSColor.labelColor]
        }

        private func pill(_ tag: String) -> NSAttributedString {
            let att = NSTextAttachment()
            att.attachmentCell = PillCell(tag: tag, font: parent.font)
            return NSAttributedString(attachment: att)
        }

        /// 현재 textStorage를 모델 문자열로 환원(첨부 → "#키워드").
        func modelString() -> String {
            guard let ts = textView?.textStorage else { return "" }
            var out = ""
            let full = NSAttributedString(attributedString: ts)
            full.enumerateAttribute(.attachment, in: NSRange(location: 0, length: full.length)) { value, range, _ in
                if let att = value as? NSTextAttachment, let cell = att.attachmentCell as? PillCell {
                    out += cell.tagText
                } else {
                    out += (full.string as NSString).substring(with: range)
                }
            }
            return out
        }

        /// 모델 문자열을 받아 #키워드를 모두 알약으로 렌더(외부 설정/초기화용).
        func render(_ model: String) {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let result = NSMutableAttributedString()
            let ns = model as NSString
            var loc = 0
            for m in hashtagRegex.matches(in: model, range: NSRange(location: 0, length: ns.length)) {
                if m.range.location > loc {
                    let plain = ns.substring(with: NSRange(location: loc, length: m.range.location - loc))
                    result.append(NSAttributedString(string: plain, attributes: baseAttrs))
                }
                result.append(pill(ns.substring(with: m.range)))
                loc = m.range.location + m.range.length
            }
            if loc < ns.length {
                result.append(NSAttributedString(string: ns.substring(from: loc), attributes: baseAttrs))
            }
            ts.setAttributedString(result)
            tv.typingAttributes = baseAttrs
        }

        /// 완성된 `#키워드␣`(공백이 따라오는 해시태그)를 알약 첨부로 치환.
        private func convertCompleted(_ tv: PillNSTextView) {
            guard let ts = tv.textStorage else { return }
            let re = try! NSRegularExpression(pattern: "#[\\p{L}0-9_]+(?=\\s)")
            let plain = ts.string
            let matches = re.matches(in: plain, range: NSRange(location: 0, length: (plain as NSString).length))
            guard !matches.isEmpty else { return }
            var sel = tv.selectedRange()
            for m in matches.reversed() {
                let tag = (plain as NSString).substring(with: m.range)
                ts.replaceCharacters(in: m.range, with: pill(tag))
                let delta = m.range.length - 1
                if sel.location >= m.range.location + m.range.length {
                    sel.location -= delta
                } else if sel.location > m.range.location {
                    sel.location = m.range.location + 1
                }
            }
            tv.setSelectedRange(sel)
            tv.typingAttributes = baseAttrs
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView, !isMutating else { return }
            // 한글 등 IME 조합 중에는 textStorage를 건드리지 않는다(조합 깨짐 방지).
            if tv.hasMarkedText() {
                parent.text = modelString()
                return
            }
            isMutating = true
            convertCompleted(tv)
            isMutating = false
            parent.text = modelString()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
