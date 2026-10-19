import AuthenticationServices
import Security
import UIKit

/// Reads the MLX wallet seed from the wallet's passkey (relying party mlx.app; the app is associated with it through
/// webcredentials:mlx.app). The seed is the passkey's user handle, released only after Face ID or Touch ID.
@MainActor
final class PasskeyReader: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum Problem: LocalizedError {
        case notWallet
        var errorDescription: String? { "This passkey isn't an MLX wallet." }
    }

    private var continuation: CheckedContinuation<Data, Error>?

    func seed() async throws -> Data {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "mlx.app")
        var challenge = Data(count: 32)
        let status = challenge.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        if status != errSecSuccess { challenge = Data(UUID().uuidString.utf8.prefix(32)) }
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .required
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { k in
            continuation = k
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let handle: Data? = (authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion)?.userID
        Task { @MainActor in
            if let handle, handle.count == 32 { self.continuation?.resume(returning: handle) } else { self.continuation?.resume(throwing: Problem.notWallet) }
            self.continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
        }
    }
}

/// The seed lives in the Keychain, on this device only.
enum SeedStore {
    private static let service = "app.mlx.ios.wallet-seed"

    static func save(_ seed: Data) {
        delete()
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: seed
        ]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load() -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data, d.count == 32 else { return nil }
        return d
    }

    static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}
