import Foundation
import UserNotifications

@MainActor final class NativeNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NativeNotifications()
    private var pending: (Record, Bool)?
    private var worker: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    private(set) var lastError: String?
    func start() { center.delegate = self }
    func update(life: Record, enabled: Bool) {
        pending = (life, enabled)
        guard worker == nil else { return }
        worker = Task {
            while let (life, enabled) = pending {
                pending = nil
                await reconcile(life: life, enabled: enabled)
            }
            worker = nil
        }
    }
    private func reconcile(life: Record, enabled: Bool) async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let plan = enabled && authorized ? ReminderPlan.make(life: life) : []
        let requests = await center.pendingNotificationRequests()
        let ids = Set(plan.map { "lifeos-" + $0.id })
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix("lifeos-") && !ids.contains($0) })
        do {
            for item in plan {
                let content = UNMutableNotificationContent()
                content.title = item.title; content.body = item.body; content.sound = .default
                content.userInfo = ["route": item.route]
                var components = CivilDate.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                components.calendar = CivilDate.calendar; components.timeZone = CivilDate.calendar.timeZone
                let request = UNNotificationRequest(identifier: "lifeos-" + item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                try await center.add(request)
            }
            lastError = nil
        } catch { lastError = "Promemoria non programmati: " + error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let route = response.notification.request.content.userInfo["route"] as? String,
              let url = URL(string: "lifeos://" + route), (LifeOSRoute(url) != nil || NativeReminderTarget(url) != nil) else { return }
        await MainActor.run {
            NativeIntentDraft.pendingURL = url
            NotificationCenter.default.post(name: .lifeOSRoute, object: url)
        }
    }
}
