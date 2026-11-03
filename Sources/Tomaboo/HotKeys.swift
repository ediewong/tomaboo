import AppKit
import Carbon.HIToolbox
import SwiftUI

/// 一个全局快捷键：按键 + 修饰键（⌃⌥⇧⌘）
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt      // NSEvent.ModifierFlags.rawValue
    var key: String          // 显示用的字符

    var display: String {
        let f = NSEvent.ModifierFlags(rawValue: modifiers)
        return (f.contains(.control) ? "⌃" : "") + (f.contains(.option) ? "⌥" : "")
            + (f.contains(.shift) ? "⇧" : "") + (f.contains(.command) ? "⌘" : "") + key.uppercased()
    }

    var carbonModifiers: UInt32 {
        let f = NSEvent.ModifierFlags(rawValue: modifiers)
        var m = 0
        if f.contains(.command) { m |= cmdKey }
        if f.contains(.option) { m |= optionKey }
        if f.contains(.control) { m |= controlKey }
        if f.contains(.shift) { m |= shiftKey }
        return UInt32(m)
    }
}

enum HotKeyAction: UInt32, CaseIterable {
    case startFinish = 1, panel = 2

    // ⌃⌥ 组合很少被其他 App 占用
    private var defaultShortcut: Shortcut {
        let mods = NSEvent.ModifierFlags([.control, .option]).rawValue
        switch self {
        case .startFinish: return Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: mods, key: "S")
        case .panel: return Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: mods, key: "T")
        }
    }

    /// 没存过 = 默认值；存了 null = 用户清除了
    var shortcut: Shortcut? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "shortcut.\(rawValue)") else { return defaultShortcut }
            return (try? JSONDecoder().decode(Shortcut?.self, from: data)) ?? nil
        }
        nonmutating set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "shortcut.\(rawValue)")
        }
    }
}

/// 用 Carbon 注册系统级快捷键，不需要辅助功能权限
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    var handlers: [HotKeyAction: () -> Void] = [:]
    private var refs: [HotKeyAction: EventHotKeyRef] = [:]

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            MainActor.assumeIsolated {
                if let action = HotKeyAction(rawValue: id.id) { HotKeyCenter.shared.handlers[action]?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// 返回 false 表示组合键已被其他 App 占用
    @discardableResult
    func register(_ action: HotKeyAction) -> Bool {
        unregister(action)
        guard let s = action.shortcut else { return true }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(s.keyCode, s.carbonModifiers, EventHotKeyID(signature: OSType(0x544D_4242), id: action.rawValue),
                                         GetApplicationEventTarget(), 0, &ref)
        refs[action] = ref
        return status == noErr
    }

    func unregister(_ action: HotKeyAction) {
        if let ref = refs.removeValue(forKey: action) { UnregisterEventHotKey(ref) }
    }

    func registerAll() { HotKeyAction.allCases.forEach { register($0) } }
    func unregisterAll() { HotKeyAction.allCases.forEach(unregister) }
}

/// 点一下开始录制，按下组合键保存；Esc 取消
struct ShortcutRecorder: View {
    let action: HotKeyAction
    @State private var shortcut: Shortcut?
    @State private var recording = false
    @State private var taken = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            if taken {
                Text("已被其他 App 占用").font(.callout).foregroundStyle(.red)
            }
            Button(action: { recording ? stop() : record() }) {
                Group {
                    if recording { Text("按下快捷键…") }
                    else if let shortcut { Text(shortcut.display) }
                    else { Text("未设置") }
                }
                .frame(minWidth: 96)
            }
            Button { save(nil) } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("清除")
                .opacity(shortcut == nil || recording ? 0 : 1)
        }
        .onAppear { shortcut = action.shortcut }
        .onDisappear { stop() }
    }

    private func record() {
        recording = true
        HotKeyCenter.shared.unregisterAll()   // 否则按下已注册的组合键会被拦截，录不到
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.intersection([.command, .option, .control]).isEmpty,
                  let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
                NSSound.beep()   // 必须带 ⌘ / ⌥ / ⌃ 之一
                return nil
            }
            let key = event.keyCode == UInt16(kVK_Space) ? "Space" : chars
            save(Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods.rawValue, key: key))
            stop()
            return nil
        }
    }

    private func stop() {
        guard recording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKeyCenter.shared.registerAll()
        taken = !HotKeyCenter.shared.register(action)
    }

    private func save(_ new: Shortcut?) {
        action.shortcut = new
        shortcut = new
        taken = !HotKeyCenter.shared.register(action)
    }
}

/// 打开/收起菜单栏面板：MenuBarExtra 没有公开接口，点一下它的状态栏按钮
/// ponytail: 依赖 SwiftUI 内部的视图结构，系统升级后失效就改用自建 NSStatusItem
@MainActor
func toggleMenuBarPanel() {
    func find(_ view: NSView) -> NSStatusBarButton? {
        (view as? NSStatusBarButton) ?? view.subviews.lazy.compactMap(find).first
    }
    for window in NSApp.windows {
        if let root = window.contentView?.superview ?? window.contentView, let button = find(root) {
            NSApp.activate(ignoringOtherApps: true)
            button.performClick(nil)
            return
        }
    }
}
