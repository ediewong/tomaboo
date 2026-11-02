import AppKit
import EventKit
import Observation

struct Category: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var calendarID: String
}

@MainActor @Observable
final class TimerModel {
    let calendarService = CalendarService()
    private(set) var calendars: [EKCalendar] = []
    private(set) var hasAccess = false

    var categories: [Category] = [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(categories), forKey: "categories") }
    }
    /// Tomaboo 自己新建的日历：只有这些允许在 App 里改颜色
    private(set) var createdCalendarIDs: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(createdCalendarIDs), forKey: "createdCalendarIDs") }
    }
    var selectedID: UUID? {
        didSet { UserDefaults.standard.set(selectedID?.uuidString, forKey: "selectedID") }
    }
    var task = ""
    var countdown = true
    var minutes = 25
    var message: String?

    private(set) var startDate: Date?
    private(set) var now = Date()
    private var ticker: Timer?

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "categories"),
           let saved = try? JSONDecoder().decode([Category].self, from: data) {
            categories = saved
        }
        selectedID = defaults.string(forKey: "selectedID").flatMap(UUID.init) ?? categories.first?.id
        createdCalendarIDs = Set(defaults.stringArray(forKey: "createdCalendarIDs") ?? [])

        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadCalendars() }
        }
        Task {
            hasAccess = await calendarService.requestAccess()
            reloadCalendars()
        }
    }

    // MARK: 日历 / 类别

    func reloadCalendars() {
        calendars = hasAccess ? calendarService.writableCalendars : []
    }

    func calendar(for category: Category?) -> EKCalendar? {
        guard let id = category?.calendarID else { return nil }
        return calendars.first { $0.calendarIdentifier == id }
    }

    var selected: Category? { categories.first { $0.id == selectedID } }

    /// calendarID 为 nil 时新建同名日历
    func addCategory(name: String, calendarID: String?, color: NSColor) {
        do {
            let id: String
            if let calendarID {
                id = calendarID
            } else {
                id = try calendarService.createCalendar(named: name, color: color).calendarIdentifier
                createdCalendarIDs.insert(id)
            }
            categories.append(Category(name: name, calendarID: id))
            if selectedID == nil { selectedID = categories.last?.id }
            reloadCalendars()
            message = nil
        } catch {
            message = "新建日历失败：\(error.localizedDescription)"
        }
    }

    // ponytail: 拖动取色时每次变化都写一次日历库，卡顿再改成停手后才保存
    func setColor(_ color: NSColor, for category: Category) {
        do {
            try calendarService.setColor(color, calendarID: category.calendarID)
            reloadCalendars()
        } catch {
            message = "修改颜色失败：\(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        if selectedID == category.id { selectedID = categories.first?.id }
    }

    // MARK: 计时

    var isRunning: Bool { startDate != nil }

    var seconds: Int {
        guard let start = startDate else { return countdown ? minutes * 60 : 0 }
        let elapsed = Int(now.timeIntervalSince(start))
        return countdown ? max(0, minutes * 60 - elapsed) : elapsed
    }

    /// 刻度尺位置（分钟）：空闲倒计时为设定时长，计时中为剩余/已用时间
    var rulerValue: Double {
        if !isRunning && countdown { return Double(minutes) }
        return Double(seconds) / 60
    }

    var display: String {
        let s = seconds
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }

    func start() {
        guard selected != nil else { message = "先选一个标签"; return }
        startDate = Date()
        now = startDate!
        message = nil
        // 时间按 startDate 计算，Timer 只负责刷新界面，睡眠/卡顿不会漂移
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = Date()
        if countdown, let start = startDate, seconds == 0 {
            NSSound(named: "Glass")?.play()
            finish(end: start.addingTimeInterval(TimeInterval(minutes * 60)))
        }
    }

    /// 完成：写入日历。不足 1 分钟视为误启动，不记录
    func finish(end: Date = Date()) {
        guard let start = startDate, let category = selected else { return }
        stop()
        guard end.timeIntervalSince(start) >= 60 else {
            message = "不足 1 分钟，未记录"
            return
        }
        let title = task.trimmingCharacters(in: .whitespaces).isEmpty ? category.name : task
        do {
            try calendarService.log(title: title, start: start, end: end, calendarID: category.calendarID)
            message = "✓ 已记录到「\(calendar(for: category)?.title ?? category.name)」"
        } catch {
            message = "写入日历失败：\(error.localizedDescription)"
        }
    }

    /// 放弃：不写入
    func stop() {
        ticker?.invalidate()
        ticker = nil
        startDate = nil
    }
}
