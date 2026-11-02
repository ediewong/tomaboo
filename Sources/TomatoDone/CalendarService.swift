import AppKit
import EventKit

/// 一个类别 = 系统日历里的一个日历（EKCalendar），颜色跟随日历。
final class CalendarService {
    let store = EKEventStore()

    struct MissingCalendar: LocalizedError {
        var errorDescription: String? { "绑定的日历不存在了，请在「管理类别」里重新绑定" }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
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
