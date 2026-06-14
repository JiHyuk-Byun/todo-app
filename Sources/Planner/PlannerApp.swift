import SwiftUI
import AppKit
import Combine

@main
struct PlannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바·스케줄러·핫키는 AppDelegate가 관리한다.
        // 여기엔 설정 창(Settings)만 두어 실행 시 창이 자동으로 뜨지 않게 한다.
        Settings {
            SettingsView()
        }
    }
}

/// 메뉴바 상태 아이템 + 드롭다운 팝오버 + 스케줄러 창 + 전역 단축키를 관리한다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate?

    private let store = Store.shared
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var schedulerWindow: NSWindow?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        registerHotKeys()
        ShortcutSettings.shared.onChange = { [weak self] in self?.registerHotKeys() }

        cancellable = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.updateStatusTitle() }
        }
        updateStatusTitle()
    }

    /// 메뉴바 전용 앱이므로 스케줄러·설정 창을 모두 닫아도 앱은 종료되면 안 된다.
    /// (SwiftUI 기본 동작은 마지막 창이 닫히면 앱을 종료시킨다 → 여기서 막는다.)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 스케줄러 창을 닫으면 다시 메뉴바 전용(액세서리)으로 — Dock 아이콘 제거.
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === schedulerWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Status item + popover

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.image
            button.imagePosition = .imageLeading
            button.font = .systemFont(ofSize: 12, weight: .semibold)
            button.target = self
            button.action = #selector(statusButtonClicked)
        }
    }

    private func updateStatusTitle() {
        let c = store.todayCounts()
        statusItem.button?.title = c.total > 0 ? " \(c.done)/\(c.total)" : ""
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(store))
    }

    @objc private func statusButtonClicked() { toggleDropdown() }

    func toggleDropdown() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            store.refreshNow()   // 자정 경과 후 "오늘"로 즉시 갱신
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closeDropdown() { popover.performClose(nil) }

    // MARK: - Scheduler window

    func showScheduler() {
        if schedulerWindow == nil {
            let host = NSHostingController(rootView: SchedulerView().environmentObject(store))
            // SwiftUI의 minHeight를 창 최소 크기로 반영 → 핀이 늘면 창이 아래로 자동 확장.
            host.sizingOptions = .minSize
            let w = NSWindow(contentViewController: host)
            w.title = "스케줄러"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 960, height: 760))
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            schedulerWindow = w
        }
        // 일반 앱 창처럼 다룬다(Cmd-Tab·재선택 가능) → 다른 앱 갔다가 돌아오기 쉬움.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        schedulerWindow?.makeKeyAndOrderFront(nil)
    }

    func toggleScheduler() {
        guard let w = schedulerWindow, w.isVisible else {
            showScheduler()
            return
        }
        if w.isKeyWindow {
            hideScheduler()          // 앞에 있을 때만 숨김
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)   // 뒤에 있으면 앞으로
        }
    }

    private func hideScheduler() {
        schedulerWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)   // 다시 메뉴바 전용
    }

    /// 드롭다운 메뉴의 "스케줄러" 버튼용 — 팝오버 닫고 창 표시.
    func openSchedulerFromMenu() {
        closeDropdown()
        showScheduler()
    }

    // MARK: - Hotkeys

    private func registerHotKeys() {
        HotKeyManager.shared.unregisterAll()
        let s = ShortcutSettings.shared
        HotKeyManager.shared.register(s.dropdown) { [weak self] in
            DispatchQueue.main.async { self?.toggleDropdown() }
        }
        HotKeyManager.shared.register(s.scheduler) { [weak self] in
            DispatchQueue.main.async { self?.toggleScheduler() }
        }
    }
}
