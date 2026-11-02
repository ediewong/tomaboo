import SwiftUI
import EventKit

@main
struct TomabooApp: App {
    @State private var model = TimerModel()

    var body: some Scene {
        MenuBarExtra {
            TimerPanel().environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("类别", id: "categories") {
            CategoriesView().environment(model)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuBarLabel: View {
    @Environment(TimerModel.self) private var model

    var body: some View {
        if model.isRunning {
            Image(nsImage: menuBarPill(name: model.selected?.name ?? "", time: model.display))
                .renderingMode(.template)
        } else {
            Image(nsImage: tomatoIcon).renderingMode(.template)
        }
    }
}

extension TimerModel {
    func color(for category: Category?) -> Color {
        calendar(for: category).map { Color(nsColor: $0.color) } ?? .accentColor
    }
}

struct ColorDot: View {
    var color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

private func openCategories(_ openWindow: OpenWindowAction) {
    openWindow(id: "categories")
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - 菜单栏计时面板（深色磨砂玻璃）

struct TimerPanel: View {
    @Environment(TimerModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 18) {
            header
            if model.categories.isEmpty {
                ContentUnavailableView {
                    Label("还没有类别", systemImage: "square.stack.3d.up")
                } description: {
                    Text("每个类别对应「日历」中的一个日历，完成的番茄钟会记录进去。")
                } actions: {
                    Button("添加类别") { openCategories(openWindow) }
                        .buttonStyle(CapsuleButtonStyle())
                }
            } else {
                TimerContent()
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.plain)
            .help("在日历中查看 Done List")

            Spacer()
            Text(model.isRunning ? (model.countdown ? "专注中" : "计时中") : "番茄钟")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()

            Menu {
                Button("管理类别…") { openCategories(openWindow) }
                    .keyboardShortcut(",")
                Divider()
                Button("退出 Tomaboo") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("设置")
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
    }
}

private struct TimerContent: View {
    @Environment(TimerModel.self) private var model
    @State private var confirmingAbandon = false

    private func confirmAbandon() {
        confirmingAbandon = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            confirmingAbandon = false
        }
    }

    var body: some View {
        @Bindable var model = model
        let tint = model.color(for: model.selected)
        let adjustable = !model.isRunning && model.countdown

        VStack(spacing: 18) {
            VStack(spacing: 14) {
                bigTime
                DurationRuler(value: model.rulerValue, tint: tint, onChange: adjustable ? { model.minutes = $0 } : nil)
                    .animation(model.isRunning ? .linear(duration: 1) : .snappy(duration: 0.2), value: model.rulerValue)
                    .opacity(model.isRunning || adjustable ? 1 : 0.4)

                HStack(spacing: 6) {
                    ColorDot(color: tint, size: 8)
                    Menu {
                        Picker("类别", selection: $model.selectedID) {
                            ForEach(model.categories) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        Text(model.selected?.name ?? "选择类别")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .disabled(model.isRunning)
            }

            ModeCard(countdown: $model.countdown)
                .disabled(model.isRunning)

            HStack(spacing: 8) {
                Image(systemName: "pencil").foregroundStyle(.secondary)
                TextField("在做什么？", text: $model.task)
                    .textFieldStyle(.plain)
                    .onSubmit { if !model.isRunning { model.start() } }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .glassFill(in: Capsule())
            .focusEffectDisabled()

            if model.isRunning && model.countdown {
                // 番茄不可分割：只能放弃，到点自动完成。点两下才放弃，防误触
                Button {
                    if confirmingAbandon { model.stop() } else { confirmAbandon() }
                } label: {
                    Text(confirmingAbandon ? "确认放弃？" : "放弃")
                        .foregroundStyle(confirmingAbandon ? Color.red : Color.primary)
                }
                .buttonStyle(CapsuleButtonStyle(prominent: false))
            } else if model.isRunning {
                Button("完成") { model.finish() }
                    .buttonStyle(CapsuleButtonStyle())
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("开始") { model.start() }
                    .buttonStyle(CapsuleButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }

            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var bigTime: some View {
        if !model.isRunning && model.countdown {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(model.minutes)")
                    .font(.system(size: 52, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
                Text("分钟")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .animation(.snappy(duration: 0.2), value: model.minutes)
        } else {
            Text(model.display)
                .font(.system(size: 52, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText(countsDown: model.countdown))
                .animation(.default, value: model.seconds)
        }
    }
}

/// 倒计时 / 正计时 二选一卡片
private struct ModeCard: View {
    @Binding var countdown: Bool

    var body: some View {
        HStack(spacing: 4) {
            half("倒计时", subtitle: "设定时长", icon: "timer", selected: countdown) { countdown = true }
            half("正计时", subtitle: "自由计时", icon: "stopwatch", selected: !countdown) { countdown = false }
        }
        .padding(4)
        .glassFill(in: RoundedRectangle(cornerRadius: 18))
    }

    private func half(_ title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 11))
                        .foregroundStyle(selected ? .secondary : .tertiary)
                }
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.selectedFill : .clear, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 白色胶囊按钮，高 40；prominent = false 时为半透明玻璃
struct CapsuleButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(prominent ? Color.white : Color.primary.opacity(0.08), in: Capsule())
            .shadow(color: .black.opacity(prominent ? 0.12 : 0), radius: 6, y: 2)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Color {
    /// 选中块：浅色玻璃上用近白，深色玻璃上用淡白
    static let selectedFill = Color(nsColor: NSColor(name: nil) {
        $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white.withAlphaComponent(0.16) : .white.withAlphaComponent(0.9)
    })
}

extension View {
    /// 面板内的分组块：随外观自适应的淡填充
    func glassFill<S: Shape>(in shape: S) -> some View {
        background(Color.primary.opacity(0.06), in: shape)
    }
}

// MARK: - 类别管理窗口

struct CategoriesView: View {
    @Environment(TimerModel.self) private var model
    @State private var newName = ""
    @State private var newCalendarID: String?   // nil = 新建同名日历
    @State private var newColor = Color.orange

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        @Bindable var model = model

        Form {
            if !model.hasAccess {
                Section {
                    LabeledContent {
                        Button("打开系统设置") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                    } label: {
                        Label("没有日历权限，番茄钟无法写入日历", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                if model.categories.isEmpty {
                    Text("还没有类别").foregroundStyle(.secondary)
                }
                ForEach($model.categories) { $category in
                    HStack(spacing: 10) {
                        // 固定宽度的首列，色点和取色器下名称都对齐
                        Group {
                            if model.createdCalendarIDs.contains(category.calendarID) {
                                ColorPicker("颜色", selection: Binding(
                                    get: { model.color(for: category) },
                                    set: { model.setColor(NSColor($0), for: category) }
                                ), supportsOpacity: false)
                                .labelsHidden()
                                .controlSize(.small)
                                .help("修改日历颜色")
                            } else {
                                ColorDot(color: model.color(for: category))
                            }
                        }
                        .frame(width: 40, alignment: .leading)
                        TextField("名称", text: $category.name, prompt: Text("名称"))
                            .labelsHidden()
                        Picker("日历", selection: $category.calendarID) {
                            ForEach(model.calendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button { model.deleteCategory(category) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("删除类别")
                        .accessibilityLabel("删除\(category.name)")
                    }
                }
            } header: {
                Text("类别")
            } footer: {
                Text("每个类别对应「日历」中的一个日历，颜色与之同步；由 Tomaboo 新建的日历可以在这里改颜色。完成的番茄钟会作为事件记录进去。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("添加类别") {
                TextField("名称", text: $newName, prompt: Text("例如：学习"))
                Picker("记录到", selection: $newCalendarID) {
                    Text("新建同名日历").tag(String?.none)
                    Divider()
                    ForEach(model.calendars, id: \.calendarIdentifier) { Text($0.title).tag(Optional($0.calendarIdentifier)) }
                }
                if newCalendarID == nil {
                    ColorPicker("日历颜色", selection: $newColor, supportsOpacity: false)
                }
                HStack {
                    if let message = model.message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("添加") {
                        model.addCategory(name: trimmedName, calendarID: newCalendarID, color: NSColor(newColor))
                        newName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedName.isEmpty || !model.hasAccess)
                }
            }
            // 选已有日历时，名称默认跟日历同名
            .onChange(of: newCalendarID) { _, id in
                if let cal = model.calendars.first(where: { $0.calendarIdentifier == id }), trimmedName.isEmpty {
                    newName = cal.title
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
    }
}
