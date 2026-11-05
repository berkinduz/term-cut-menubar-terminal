import AppKit
import Combine
import PeekshCore
import UserNotifications

final class CommandCompletionNotifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var permissionMessage: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var onOpenSession: ((UUID) -> Void)?
    var isTerminalVisible: (() -> Bool)?
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func refreshAuthorization() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.permissionMessage = settings.authorizationStatus == .denied
                    ? "Enable Peeksh in System Settings → Notifications to receive alerts." : nil
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled else { return }
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            if settings.authorizationStatus == .notDetermined {
                self.center.requestAuthorization(options: [.alert]) { [weak self] _, error in
                    if let error {
                        DispatchQueue.main.async { self?.permissionMessage = error.localizedDescription }
                    } else { self?.refreshAuthorization() }
                }
            } else { self.refreshAuthorization() }
        }
    }

    func commandCompleted(_ session: TerminalSession, duration: TimeInterval, preferences: AppPreferences) {
        guard CommandCompletionPolicy.shouldNotify(enabled: preferences.commandNotificationsEnabled,
                                                  terminalVisible: isTerminalVisible?() ?? false,
                                                  duration: duration,
                                                  minimumDuration: preferences.notificationMinimumDuration) else { return }
        let content = UNMutableNotificationContent()
        if case .failed(let code) = session.activity {
            content.title = "Command Failed"
            content.body = "\(session.compactTitle) · Exit \(code) after \(Int(duration))s"
        } else {
            content.title = "Command Finished"
            content.body = "\(session.compactTitle) · Finished after \(Int(duration))s"
        }
        content.userInfo = ["sessionID": session.id.uuidString]
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { [weak self] error in
            if let error { DispatchQueue.main.async { self?.permissionMessage = error.localizedDescription } }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { [weak self] in
            completionHandler(self?.isTerminalVisible?() == true ? [] : [.banner])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = (response.notification.request.content.userInfo["sessionID"] as? String).flatMap(UUID.init(uuidString:))
        DispatchQueue.main.async { [weak self] in
            if let id { self?.onOpenSession?(id) }
            completionHandler()
        }
    }
}
