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
final class AppDelegate: NSObject, NSApplicationDelegate {
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
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(store))
    }

    @objc private func statusButtonClicked() { toggleDropdown() }

    func toggleDropdown() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
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
            let w = NSWindow(contentViewController: host)
            w.title = "스케줄러"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 860, height: 600))
            w.isReleasedWhenClosed = false
            w.center()
            schedulerWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        schedulerWindow?.makeKeyAndOrderFront(nil)
    }

    func toggleScheduler() {
        if let w = schedulerWindow, w.isVisible {
            w.orderOut(nil)
        } else {
            showScheduler()
        }
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
