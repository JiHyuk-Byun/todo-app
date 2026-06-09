import SwiftUI

/// 환경설정 창: 전역 단축키 지정.
struct SettingsView: View {
    @ObservedObject private var settings = ShortcutSettings.shared

    var body: some View {
        Form {
            Section("전역 단축키") {
                LabeledContent("드롭다운 열기") {
                    ShortcutRecorder(shortcut: $settings.dropdown)
                        .frame(width: 120, height: 24)
                }
                LabeledContent("스케줄러 열기") {
                    ShortcutRecorder(shortcut: $settings.scheduler)
                        .frame(width: 120, height: 24)
                }
                Text("필드를 클릭한 뒤 원하는 키 조합을 누르세요. (보조키 ⌘⌥⌃⇧ 필수)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("기본값으로 되돌리기") { settings.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
    }
}
