import CryptoKit
import LocalAuthentication
import SwiftUI
import UserNotifications

/// Everything the app knows: who is signed in, the wallet's Macs (refreshed every 15 seconds while the app is open),
/// commands sent to them, and notification and lock settings.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    enum Phase: Equatable { case starting, signedOut, locked, ready }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var me: Me?
    @Published private(set) var loading = false
    @Published var error: String?
    @Published var pushError: String?
    @Published private(set) var pushOn = UserDefaults.standard.bool(forKey: "push.on")
    @Published var lockWithFaceID: Bool = UserDefaults.standard.object(forKey: "lock.faceid") as? Bool ?? true {
        didSet { UserDefaults.standard.set(lockWithFaceID, forKey: "lock.faceid") }
    }
    /// Commands sent from this phone, by Mac, until the Mac reports it has applied them.
    @Published private(set) var sent: [String: Date] = [:]

    let demo = ProcessInfo.processInfo.arguments.contains("-demo")
    private var api: API?
    private var poll: Task<Void, Never>?
    private var seed: Data?

    // MARK: start

    func start() {
        if demo {
            // "-demo -signin" shows the sign-in screen for screenshots
            if ProcessInfo.processInfo.arguments.contains("-signin") { phase = .signedOut; return }
            me = Demo.me
            phase = .ready
            return
        }
        guard phase == .starting else { return }
        if let s = SeedStore.load() {
            seed = s
            phase = lockWithFaceID ? .locked : .ready
            if phase == .ready { Task { await resume() } }
        } else {
            phase = .signedOut
        }
    }

    func unlock() async {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock MLX")
            if ok {
                withAnimation(.smooth(duration: 0.4)) { phase = .ready }
                await resume()
            }
        } catch {
            self.error = nil
        }
    }

    /// Back in the foreground (or just unlocked): rebuild the session from the stored seed and refresh.
    func resume() async {
        if demo { return }
        guard let seed else { return }
        if api == nil {
            do { try await connect(seed: seed) } catch { self.error = error.localizedDescription; return }
        }
        await refresh()
        startPolling()
    }

    // MARK: sign in

    func signInWithPasskey() async {
        error = nil
        loading = true
        defer { loading = false }
        do {
            let s = try await PasskeyReader().seed()
            try await finish(seed: s)
        } catch let e as NSError where e.domain == "com.apple.AuthenticationServices.AuthorizationError" && e.code == 1001 {
            // cancelled
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signIn(phrase: String) async -> Bool {
        error = nil
        loading = true
        defer { loading = false }
        do {
            let s = try RecoveryPhrase.seed(from: phrase)
            try await finish(seed: s)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func finish(seed s: Data) async throws {
        try await connect(seed: s)
        SeedStore.save(s)
        seed = s
        withAnimation(.smooth(duration: 0.45)) { phase = .ready }
        await refresh()
        startPolling()
    }

    private func connect(seed s: Data) async throws {
        let key = try WalletCrypto.signingKey(seed: s)
        let pk = WalletCrypto.hex(key.publicKey.rawRepresentation)
        async let stats = API.open("/api/stats", as: StatsReply.self)
        let owner: KeyReply
        do {
            owner = try await API.open("/api/key/\(pk)", as: KeyReply.self)
        } catch {
            throw API.Failure.server("No MLX wallet uses this key. Create your wallet on mlx.app first.")
        }
        let network = try await stats
        api = API(account: owner.account.name, chain: network.chain, key: key)
    }

    func signOut() async {
        if pushOn, let t = UserDefaults.standard.string(forKey: "push.token") {
            _ = try? await api?.post("/api/companion/push", ["token": t, "on": false], as: OK.self)
        }
        poll?.cancel()
        SeedStore.delete()
        UserDefaults.standard.removeObject(forKey: "push.on")
        api = nil
        seed = nil
        pushOn = false
        withAnimation(.smooth(duration: 0.45)) {
            me = nil
            phase = .signedOut
        }
    }

    // MARK: data

    func refresh() async {
        if demo { return }
        guard let api else { return }
        do {
            let fresh = try await api.get("/api/companion/me", as: Me.self)
            // a Mac has applied what this phone sent once nothing is pending for it
            for mac in fresh.macs where mac.pending == 0 { sent[mac.pk] = nil }
            withAnimation(.smooth(duration: 0.4)) { me = fresh }
            error = nil
        } catch {
            if me == nil { self.error = error.localizedDescription }
        }
    }

    func startPolling() {
        poll?.cancel()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await self?.refresh()
            }
        }
    }

    func stopPolling() { poll?.cancel() }

    // MARK: commands

    func send(_ mac: Me.Mac, action: String, limits: [String: Any]? = nil) async {
        if demo {
            sent[mac.pk] = Date()
            return
        }
        guard let api else { return }
        var body: [String: Any] = ["device": mac.pk, "action": action]
        if let limits { body["limits"] = limits }
        do {
            _ = try await api.post("/api/companion/command", body, as: OK.self)
            withAnimation(.smooth(duration: 0.3)) { sent[mac.pk] = Date() }
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: notifications

    func setPush(_ on: Bool) async {
        pushError = nil
        if on {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else {
                pushError = "Allow notifications for MLX in Settings to turn these on."
                pushOn = false
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            pushOn = true
        } else {
            if let t = UserDefaults.standard.string(forKey: "push.token") {
                _ = try? await api?.post("/api/companion/push", ["token": t, "on": false], as: OK.self)
            }
            UIApplication.shared.unregisterForRemoteNotifications()
            pushOn = false
        }
        UserDefaults.standard.set(pushOn, forKey: "push.on")
    }

    func registerPush(token: String) async {
        UserDefaults.standard.set(token, forKey: "push.token")
        guard pushOn, let api else { return }
        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        do {
            _ = try await api.post("/api/companion/push", ["token": token, "sandbox": sandbox, "lang": "en", "on": true], as: OK.self)
        } catch {
            pushError = error.localizedDescription
        }
    }
}
