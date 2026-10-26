import SwiftUI
import UserNotifications

@main
struct MLXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Brand.orange)
                .onAppear { store.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if store.phase == .ready { Task { await store.resume() } }
            case .background:
                store.stopPolling()
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in await Store.shared.registerPush(token: hex) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in Store.shared.pushError = message }
    }

    // banners while the app is open too
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        ZStack {
            switch store.phase {
            case .starting:
                Color(.systemGroupedBackground).ignoresSafeArea()
            case .signedOut:
                SignInView().transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .locked:
                LockView().transition(.opacity)
            case .ready:
                MainView().transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.smooth(duration: 0.45), value: store.phase)
    }
}
