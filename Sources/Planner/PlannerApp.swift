import SwiftUI

@main
struct PlannerApp: App {
    @StateObject private var store = Store()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 상단 메뉴바 아이콘 + 드롭다운(window 스타일).
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            // 커스텀 아이콘 + 오늘 완료/전체 카운트.
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        // 스케줄러 창 (메뉴바에서 버튼으로 연다).
        Window("스케줄러", id: "scheduler") {
            SchedulerView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
    }
}

/// Dock 아이콘 없이 메뉴바 전용(accessory) 앱으로 동작하게 한다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
