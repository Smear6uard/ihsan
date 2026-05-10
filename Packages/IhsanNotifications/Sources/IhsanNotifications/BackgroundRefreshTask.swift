import Foundation
import OSLog

#if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
@preconcurrency import BackgroundTasks
#endif

public enum BackgroundRefreshTask {
    public static let identifier = "com.sameerstudios.ihsan.refresh-notifications"

    private static let logger = Logger(subsystem: "com.sameerstudios.ihsan", category: "BackgroundRefreshTask")

    @discardableResult
    public static func register(scheduler: NotificationScheduler = .shared) -> Bool {
        #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task: task, scheduler: scheduler)
        }
        if registered {
            scheduleTaskAgain()
        }
        return registered
        #else
        logger.info("BackgroundTasks is unavailable on this platform; notification refresh registration skipped.")
        return false
        #endif
    }

    public static func scheduleNextRefresh() throws {
        #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = nextRefreshDate()
        try BGTaskScheduler.shared.submit(request)
        #else
        logger.info("BackgroundTasks is unavailable on this platform; notification refresh scheduling skipped.")
        #endif
    }

    public static func nextRefreshDate(
        after date: Date = Date(),
        calendar inputCalendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone

        let startOfDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 3, minute: 0, second: 0, of: nextDay) ?? nextDay.addingTimeInterval(10_800)
    }

    #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
    private static func handle(task: BGTask, scheduler: NotificationScheduler) {
        scheduleTaskAgain()

        let refreshTask = Task {
            do {
                try await scheduler.rebuildSchedule()
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Nightly notification schedule rebuild failed: \(String(describing: error), privacy: .public)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func scheduleTaskAgain() {
        do {
            try scheduleNextRefresh()
        } catch {
            logger.error("Could not schedule next background notification refresh: \(String(describing: error), privacy: .public)")
        }
    }
    #endif
}
