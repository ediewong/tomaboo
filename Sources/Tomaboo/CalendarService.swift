import AppKit
import EventKit

/// 一个类别 = 系统日历里的一个日历（EKCalendar），颜色跟随日历。
final class CalendarService {
    private(set) var store = EKEventStore()

    struct MissingCalendar: LocalizedError {
        var errorDescription: String? { String(localized: "这个标签对应的日历找不到了，请在设置的「标签」里重新选一个日历") }
    }

    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        // 首次授权时，授权前创建的 store 读不到任何日历，换一个新的
        if granted { store = EKEventStore() }
        return granted
    }

    var writableCalendars: [EKCalendar] {
        store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { $0.title < $1.title }
    }

    func createCalendar(named name: String, color: NSColor) throws -> EKCalendar {
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = name
        cal.color = color
        // 优先放「Mac」本地日历组；开了 iCloud 没有本地源时用默认日历所在的源
        cal.source = store.sources.first { $0.sourceType == .local } ?? store.defaultCalendarForNewEvents?.source
        try store.saveCalendar(cal, commit: true)
        return cal
    }

    func setColor(_ color: NSColor, calendarID: String) throws {
        guard let cal = store.calendar(withIdentifier: calendarID) else { throw MissingCalendar() }
        cal.color = color
        try store.saveCalendar(cal, commit: true)
    }

    func log(title: String, start: Date, end: Date, calendarID: String) throws {
        guard let cal = store.calendar(withIdentifier: calendarID) else { throw MissingCalendar() }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.calendar = cal
        try store.save(event, span: .thisEvent)
    }
}
