import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("settingsTab") private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings()
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag("general")
            CategoriesView()
                .tabItem { Label("标签", systemImage: "tag") }
                .tag("tags")
            ShortcutSettings()
                .tabItem { Label("快捷键", systemImage: "keyboard") }
                .tag("shortcuts")
        }
        .frame(width: 480, height: 520)
    }
}

@MainActor
func openSettings(_ openWindow: OpenWindowAction, tab: String? = nil) {
    if let tab { UserDefaults.standard.set(tab, forKey: "settingsTab") }
    openWindow(id: "settings")
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - 通用

private struct GeneralSettings: View {
    @Environment(Updater.self) private var updater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage("appLanguage") private var language = "system"
    @State private var languageChanged = false

    var body: some View {
        @Bindable var updater = updater

        Form {
            Section {
                Toggle("登录时打开", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.callout).foregroundStyle(.red)
                }

                Picker("语言", selection: $language) {
                    Text("跟随系统").tag("system")
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                }
                .onChange(of: language) { _, code in
                    if code == "system" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([code], forKey: "AppleLanguages")
                    }
                    languageChanged = true
                }
                if languageChanged {
                    LabeledContent {
                        Button("立即重启", action: relaunch)
                    } label: {
                        Text("重启 Tomaboo 后生效").foregroundStyle(.secondary)
                    }
                }
            }

            Section("更新") {
                LabeledContent("当前版本", value: updater.currentVersion)
                Toggle("自动检查更新", isOn: $updater.autoCheck)
                LabeledContent {
                    Button("检查更新") { Task { await updater.check() } }
                        .disabled(updater.state == .checking)
                } label: {
                    switch updater.state {
                    case .idle: Text("")
                    case .checking: Text("正在检查…").foregroundStyle(.secondary)
                    case .upToDate: Text("已是最新版本").foregroundStyle(.secondary)
                    case .failed: Text("检查失败，请稍后再试").foregroundStyle(.secondary)
                    case .available(let version, let url):
                        Link("有新版本 \(version)，前往下载", destination: url)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func relaunch() {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "sleep 0.5; open \"$0\"", Bundle.main.bundlePath]
        try? shell.run()
        NSApp.terminate(nil)
    }
}

// MARK: - 快捷键

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("开始 / 完成") { ShortcutRecorder(action: .startFinish) }
                LabeledContent("打开面板") { ShortcutRecorder(action: .panel) }
            } footer: {
                Text("在任何 App 里都能用。「开始 / 完成」：空闲时开始计时，正计时中完成；倒计时中不响应，番茄不可分割。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 检查更新

@MainActor @Observable
final class Updater {
    enum State: Equatable {
        case idle, checking, upToDate, failed
        case available(version: String, url: URL)
    }

    private(set) var state = State.idle
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    var autoCheck = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoCheck, forKey: "autoCheckUpdates") }
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: URL
    }

    // ponytail: 只在启动时自动检查一次，常驻很久不重启的话要靠手动检查
    func checkOnLaunch() async {
        if autoCheck { await check() }
    }

    func check() async {
        state = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/ediewong/tomaboo/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = String(release.tag_name.trimmingPrefix("v"))
            state = latest.compare(currentVersion, options: .numeric) == .orderedDescending
                ? .available(version: latest, url: release.html_url)
                : .upToDate
        } catch {
            state = .failed
        }
    }
}
