import SwiftUI
import AppKit

/// 커스텀 월간 캘린더. 날짜별 할 일 유무/완료를 점으로 표시하고,
/// 선택 pill·오늘 ring·월 이동을 제공한다.
struct MonthCalendarView: View {
    @EnvironmentObject private var store: Store
    @Binding var selection: Date

    @State private var month: Date = Date()   // 표시 중인 달의 기준 날짜
    @State private var scrollAccum: CGFloat = 0
    @State private var gestureShifted = false  // 한 트랙패드 제스처당 1회만 이동
    @State private var isOverCalendar = false
    @State private var scrollMonitor: Any?
    @State private var showMonthPicker = false
    @State private var dropTargetDay: Date?
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayHeader
            grid
        }
        .onContinuousHover { phase in
            switch phase {
            case .active: isOverCalendar = true
            case .ended: isOverCalendar = false
            }
        }
        .onAppear { month = selection; installScrollMonitor() }
        .onDisappear { removeScrollMonitor(); isOverCalendar = false }
    }

    /// 마우스가 달력 위에 있을 때의 스크롤만 가로채 월을 바꾼다(다른 곳 스크롤은 그대로).
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard isOverCalendar else { return event }
            handleScroll(event)
            return nil
        }
    }

    private func removeScrollMonitor() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
    }

    /// 스크롤로 월 이동: 위로 → 다음 달, 아래로 → 이전 달.
    /// 관성(momentum)은 무시하고, 트랙패드 한 제스처당 한 달만 이동.
    private func handleScroll(_ event: NSEvent) {
        if event.momentumPhase != [] { return }          // 관성 스크롤 무시
        let threshold: CGFloat = 8

        if event.phase != [] {
            // 트랙패드 제스처
            if event.phase == .began { gestureShifted = false; scrollAccum = 0 }
            if event.phase == .ended || event.phase == .cancelled {
                gestureShifted = false; scrollAccum = 0; return
            }
            if !gestureShifted {
                scrollAccum += event.scrollingDeltaY
                if abs(scrollAccum) >= threshold {
                    shiftMonth(scrollAccum < 0 ? 1 : -1)
                    gestureShifted = true
                }
            }
        } else {
            // 마우스 휠(단계 정보 없음): 노치당 한 번
            scrollAccum += event.scrollingDeltaY
            if abs(scrollAccum) >= threshold {
                shiftMonth(scrollAccum < 0 ? 1 : -1)
                scrollAccum = 0
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()
            Button { showMonthPicker.toggle() } label: {
                Text(month.formatted(.dateTime.year().month()))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help("연·월 선택")
            .popover(isPresented: $showMonthPicker, arrowEdge: .bottom) {
                MonthYearPicker(month: $month)
            }
            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// gridDays(42칸)를 7개씩 6주로 나눈다.
    private var weekRows: [[Date]] {
        let days = gridDays
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private var grid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let cellW = (geo.size.width - spacing * 6) / 7
            // 6주 행. 셀 높이는 남는 세로 공간을 균등 분배 → 공간이 줄면 셀도 비율로 작아진다.
            let cellH = (geo.size.height - spacing * 5) / 6
            VStack(spacing: spacing) {
                ForEach(weekRows.indices, id: \.self) { wi in
                    HStack(spacing: spacing) {
                        ForEach(weekRows[wi], id: \.self) { day in
                            cell(day, width: cellW, height: cellH)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func cell(_ day: Date, width: CGFloat, height: CGFloat) -> some View {
        DayCell(
            day: day,
            inMonth: cal.isDate(day, equalTo: month, toGranularity: .month),
            isToday: cal.isDateInToday(day),
            isSelected: cal.isDate(day, inSameDayAs: selection),
            isDropTarget: dropTargetDay.map { cal.isDate($0, inSameDayAs: day) } ?? false,
            status: store.dayStatus(on: day),
            cellWidth: width,
            cellHeight: height
        )
        .frame(width: width, height: height)
        .onTapGesture { select(day) }
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let id = UUID(uuidString: s),
                  let t = store.todo(id: id) else { return false }
            store.moveTodo(t, toDay: day)
            return true
        } isTargeted: { targeted in
            dropTargetDay = targeted ? day : nil
        }
    }

    // MARK: Logic

    private func shiftMonth(_ n: Int) {
        withAnimation(.snappy(duration: 0.2)) {
            month = cal.date(byAdding: .month, value: n, to: month) ?? month
        }
    }

    private func select(_ day: Date) {
        withAnimation(.snappy(duration: 0.15)) {
            selection = day
            if !cal.isDate(day, equalTo: month, toGranularity: .month) {
                month = day
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols          // index 0 = 일요일
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 표시 달의 첫 주 시작부터 6주(42칸).
    private var gridDays: [Date] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month),
              let firstWeek = cal.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        var days: [Date] = []
        var d = firstWeek.start
        for _ in 0..<42 {
            days.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return days
    }
}

/// 연·월 선택 팝오버.
private struct MonthYearPicker: View {
    @Binding var month: Date
    private let cal = Calendar.current
    @State private var year = 2026
    @State private var mon = 1

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("", selection: $year) {
                    ForEach(yearRange, id: \.self) { Text(String(format: "%d년", $0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 110)

                Picker("", selection: $mon) {
                    ForEach(1...12, id: \.self) { Text("\($0)월").tag($0) }
                }
                .labelsHidden()
                .frame(width: 80)
            }
            Button("오늘로 이동") { setToday() }
                .buttonStyle(.borderless)
        }
        .padding(16)
        .onAppear {
            year = cal.component(.year, from: month)
            mon = cal.component(.month, from: month)
        }
        .onChange(of: year) { _, _ in apply() }
        .onChange(of: mon) { _, _ in apply() }
    }

    private var yearRange: [Int] {
        let y = cal.component(.year, from: Date())
        return Array((y - 10)...(y + 10))
    }

    private func apply() {
        var c = DateComponents()
        c.year = year; c.month = mon; c.day = 1
        if let d = cal.date(from: c) { month = d }
    }

    private func setToday() {
        let now = Date()
        year = cal.component(.year, from: now)
        mon = cal.component(.month, from: now)
        month = now
    }
}

/// 캘린더의 한 날짜 칸. 할당된 셀 크기(cellWidth/Height)에 맞춰 비율로 작아진다.
private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    var isDropTarget: Bool = false
    let status: (total: Int, done: Int)
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    private let cal = Calendar.current

    private var complete: Bool { status.total > 0 && status.done == status.total }

    /// 숫자 원의 지름: 셀 크기에 맞춰 스케일(아래 진행표시 공간 확보, 상·하한 적용).
    private var circle: CGFloat {
        let byWidth = cellWidth * 0.82
        let byHeight = cellHeight - 16          // 아래 진행 표시 영역 확보
        return min(30, max(15, min(byWidth, byHeight)))
    }

    /// 진행 표시를 그릴 만큼 셀이 충분히 큰가.
    private var showIndicator: Bool { cellHeight - circle >= 12 }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: circle * 0.46, weight: isSelected ? .bold : .regular))
                .frame(width: circle, height: circle)
                .background(Circle().fill(numberBackground))
                .overlay(
                    Circle().strokeBorder(
                        isToday && !isSelected ? Color.accentColor : .clear,
                        lineWidth: 1.2)
                )
                .foregroundStyle(numberForeground)
            if showIndicator { indicator }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTarget ? Color.accentColor.opacity(0.18) : .clear)
        )
        .opacity(inMonth ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private var numberBackground: Color {
        if isSelected { return .accentColor }
        if complete { return .green.opacity(0.18) }
        return .clear
    }

    private var numberForeground: Color {
        if isSelected { return .white }
        if complete { return .green }
        return .primary
    }

    @ViewBuilder private var indicator: some View {
        if status.total > 0 {
            let tint: Color = complete ? .green : .accentColor
            let fraction = CGFloat(status.done) / CGFloat(status.total)
            let barWidth = min(circle, cellWidth * 0.7)
            VStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.2)).frame(width: barWidth, height: 3)
                    Capsule().fill(tint).frame(width: barWidth * fraction, height: 3)
                }
                Text("\(status.done)/\(status.total)")
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(complete ? .green : .secondary)
            }
        }
    }
}
