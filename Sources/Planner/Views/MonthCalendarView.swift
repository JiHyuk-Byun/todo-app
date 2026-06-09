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

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                  spacing: 6) {
            ForEach(gridDays, id: \.self) { day in
                DayCell(
                    day: day,
                    inMonth: cal.isDate(day, equalTo: month, toGranularity: .month),
                    isToday: cal.isDateInToday(day),
                    isSelected: cal.isDate(day, inSameDayAs: selection),
                    status: store.dayStatus(on: day)
                )
                .onTapGesture { select(day) }
            }
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

/// 캘린더의 한 날짜 칸.
private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let status: (total: Int, done: Int)

    private let cal = Calendar.current

    private var complete: Bool { status.total > 0 && status.done == status.total }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                .frame(width: 26, height: 26)
                .background(Circle().fill(numberBackground))
                .overlay(
                    Circle().strokeBorder(
                        isToday && !isSelected ? Color.accentColor : .clear,
                        lineWidth: 1.2)
                )
                .foregroundStyle(numberForeground)
            indicator.frame(height: 16)
        }
        .frame(maxWidth: .infinity)
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
            VStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.2)).frame(width: 22, height: 3)
                    Capsule().fill(tint).frame(width: 22 * fraction, height: 3)
                }
                Text("\(status.done)/\(status.total)")
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(complete ? .green : .secondary)
            }
        } else {
            Color.clear
        }
    }
}
