import Foundation

// MARK: - Configuration

/// Credentials for the Firebase project that backs Moon Place authentication.
/// Create a project at https://console.firebase.google.com, enable the
/// Email/Password provider and paste the Web API Key below. The client talks to
/// the Identity Toolkit REST API directly, so no Firebase SDK package is
/// required and the GitHub Actions build stays dependency-free.
struct FirebaseConfiguration {
    let apiKey: String
    let syntheticEmailDomain: String

    static let moonPlace = FirebaseConfiguration(
        apiKey: "AIzaSyADR8MgW6mknGWDBlZYXO3QpdNLAQDeiDY",
        syntheticEmailDomain: "moonexternal.app"
    )

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    func endpoint(_ action: String) -> URL {
        URL(string: "https://identitytoolkit.googleapis.com/v1/\(action)?key=\(apiKey)")!
    }

    var refreshEndpoint: URL {
        URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!
    }
}

// MARK: - Errors

enum FirebaseAuthenticationError: LocalizedError {
    case notConfigured
    case invalidResponse
    case transport(URLError, host: String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase is not configured. Paste your Web API Key in FirebaseConfiguration.moonPlace."
        case .invalidResponse:
            return "Firebase returned an invalid response."
        case .transport(let error, let host):
            switch error.code {
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .clientCertificateRejected,
                 .clientCertificateRequired:
                return "Secure connection to \(host) failed (TLS). Verify the device date/time or try another network."
            case .appTransportSecurityRequiresSecureConnection:
                return "The connection to \(host) was blocked: HTTPS is required."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Could not reach \(host). Check your Internet connection and try again."
            case .notConnectedToInternet:
                return "No Internet connection. Connect to Wi-Fi or mobile data and try again."
            case .timedOut:
                return "The connection to \(host) timed out. Try again."
            default:
                return "Network error contacting \(host): \(error.localizedDescription)"
            }
        case .server(let message):
            return message
        }
    }

    /// Translates raw Identity Toolkit error messages into friendly text.
    static func friendlyMessage(for code: String) -> String {
        switch code {
        case "EMAIL_EXISTS":
            return "An account with this username already exists. Try logging in instead."
        case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND":
            return "Invalid username or password."
        case "INVALID_EMAIL":
            return "The username contains characters that are not allowed."
        case "WEAK_PASSWORD":
            return "The password must be at least 6 characters long."
        case "TOO_MANY_ATTEMPTS_TRY_LATER":
            return "Too many attempts. Please try again later."
        case "OPERATION_NOT_ALLOWED":
            return "Email/password sign-in is disabled for this Firebase project."
        case "USER_DISABLED":
            return "This account has been disabled."
        case "ADMIN_ONLY_OPERATION":
            return "This operation is restricted."
        case "API_KEY_NOT_VALID", "API_KEY_INVALID", "INVALID_API_KEY":
            return "The Firebase API key is invalid. Check FirebaseConfiguration.moonPlace."
        case "QUOTA_EXCEEDED":
            return "The Firebase project quota was exceeded. Try again later."
        default:
            if code.hasPrefix("WEAK_PASSWORD") {
                return "The password must be at least 6 characters long."
            }
            if code.hasPrefix("EMAIL_EXISTS") {
                return "An account with this username already exists. Try logging in instead."
            }
            if code.hasPrefix("TOO_MANY_ATTEMPTS") {
                return "Too many attempts. Please try again later."
            }
            return "Firebase error: \(code)"
        }
    }
}

// MARK: - Client

/// Firebase Authentication backend for Moon Place, implementing the same
/// `MoonPlaceSessionBackend` contract as the Supabase client.
///
/// - Login/registration use the Identity Toolkit email/password endpoints;
///   the username is mapped to the synthetic email `user@<domain>`.
/// - ID and refresh tokens are stored in the Keychain, the display profile in
///   UserDefaults, so sessions restore automatically on launch.
final class FirebaseAuthenticationClient: MoonPlaceSessionBackend {
    private let configuration: FirebaseConfiguration

    private static let profileKey = "moon.place.firebase.profile.v1"
    private static let idTokenService = "moon.place.firebase.id-token"
    private static let refreshTokenService = "moon.place.firebase.refresh-token"

    static var isConfigured: Bool { FirebaseConfiguration.moonPlace.isConfigured }

    init(configuration: FirebaseConfiguration = .moonPlace) {
        self.configuration = configuration
    }

    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult {
        // Solo validar la key contra Firestore y crear la sesión sin Firebase Auth
        let expirationDate = try await MoonKeyValidator.validate(key: key, hwid: MoonKeyValidator.deviceHWID())
        
        let dummyUsername = key.count > 6 ? String(key.prefix(6)) : key
        let result = MoonPlaceAuthenticationResult(
            username: dummyUsername,
            phone: "",
            expiresAt: expirationDate
        )
        
        storeProfile(MoonPlaceStoredProfile(username: dummyUsername, phone: "", expiresAt: expirationDate))
        return result
    }

    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult {
        try requireConfigured()
        let payload: [String: Any] = [
            "email": syntheticEmail(for: username),
            "password": password,
            "returnSecureToken": true
        ]
        let body = try await authRequest(endpoint: configuration.endpoint("accounts:signUp"), payload: payload)
        return try finishAuthentication(username: username, phone: phone, body: body)
    }

    // MARK: Session

    func cachedProfile() -> MoonPlaceStoredProfile? {
        loadProfile()
    }

    /// Restores a stored session. Returns the cached profile while the ID token
    /// is still valid and refreshes it through securetoken.googleapis.com once
    /// it has expired. Clears the session when Firebase rejects the refresh.
    func restoreSession() async -> MoonPlaceAuthenticationResult? {
        guard configuration.isConfigured, let profile = loadProfile() else { return nil }

        if let idToken = FirebaseTokenStore.load(service: Self.idTokenService, account: profile.username),
           !isExpired(jwt: idToken) {
            return MoonPlaceAuthenticationResult(
                username: profile.username,
                phone: profile.phone,
                expiresAt: profile.expiresAt
            )
        }

        guard let refreshToken = FirebaseTokenStore.load(service: Self.refreshTokenService, account: profile.username) else {
            clearSession(username: profile.username)
            return nil
        }

        do {
            let body = try await refreshRequest(refreshToken: refreshToken)
            guard let idToken = body["id_token"] as? String,
                  let rotatedRefresh = body["refresh_token"] as? String else {
                clearSession(username: profile.username)
                return nil
            }
            FirebaseTokenStore.save(idToken, service: Self.idTokenService, account: profile.username)
            FirebaseTokenStore.save(rotatedRefresh, service: Self.refreshTokenService, account: profile.username)
            return MoonPlaceAuthenticationResult(
                username: profile.username,
                phone: profile.phone,
                expiresAt: profile.expiresAt
            )
        } catch {
            log("moon-firebase: session restore failed — \(error.localizedDescription)")
            clearSession(username: profile.username)
            return nil
        }
    }

    func signOut(username: String) {
        clearSession(username: username)
    }

    private func requireConfigured() throws {
        guard configuration.isConfigured else {
            throw FirebaseAuthenticationError.notConfigured
        }
    }

    private func syntheticEmail(for username: String) -> String {
        let cleaned = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        return "\(cleaned)@\(configuration.syntheticEmailDomain)"
    }

    private func finishAuthentication(
        username: String,
        phone: String,
        body: [String: Any]
    ) throws -> MoonPlaceAuthenticationResult {
        guard let idToken = body["idToken"] as? String,
              let refreshToken = body["refreshToken"] as? String else {
            throw FirebaseAuthenticationError.invalidResponse
        }
        let expiresIn = (body["expiresIn"] as? String).flatMap(TimeInterval.init) ?? 3600
        let expiresAt = Date().addingTimeInterval(expiresIn)

        FirebaseTokenStore.save(idToken, service: Self.idTokenService, account: username)
        FirebaseTokenStore.save(refreshToken, service: Self.refreshTokenService, account: username)
        storeProfile(MoonPlaceStoredProfile(username: username, phone: phone, expiresAt: expiresAt))

        return MoonPlaceAuthenticationResult(
            username: username,
            phone: phone,
            expiresAt: expiresAt
        )
    }

    // MARK: Transport

    private func authRequest(endpoint: URL, payload: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return try await execute(request)
    }

    private func refreshRequest(refreshToken: String) async throws -> [String: Any] {
        var request = URLRequest(url: configuration.refreshEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["grant_type": "refresh_token", "refresh_token": refreshToken]
        )
        return try await execute(request)
    }

    private func execute(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            let host = request.url?.host ?? "unknown"
            log("moon-firebase: transport error \(error.code.rawValue) — \(error.localizedDescription) (\(host))")
            throw FirebaseAuthenticationError.transport(error, host: host)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw FirebaseAuthenticationError.invalidResponse
        }

        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard (200..<300).contains(http.statusCode) else {
            let raw = object["error"] as? [String: Any]
            let code = raw?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw FirebaseAuthenticationError.server(FirebaseAuthenticationError.friendlyMessage(for: code))
        }

        guard !object.isEmpty else {
            throw FirebaseAuthenticationError.invalidResponse
        }
        return object
    }

    // MARK: Profile

    private func storeProfile(_ profile: MoonPlaceStoredProfile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.profileKey)
    }

    private func loadProfile() -> MoonPlaceStoredProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.profileKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MoonPlaceStoredProfile.self, from: data)
    }

    private func clearSession(username: String) {
        FirebaseTokenStore.delete(service: Self.idTokenService, account: username)
        FirebaseTokenStore.delete(service: Self.refreshTokenService, account: username)
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
    }

    // MARK: Tokens

    private func isExpired(jwt token: String) -> Bool {
        guard let expiration = jwtExpiration(token) else { return false }
        return expiration <= Date()
    }

    private func jwtExpiration(_ token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiration = (object["exp"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return Date(timeIntervalSince1970: expiration)
    }
}

// MARK: - Keychain token store

/// Keychain-backed store for Firebase tokens (a private mirror of the store
/// used by the Supabase client, kept local to avoid cross-file coupling).
private enum FirebaseTokenStore {
    static func save(_ token: String, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}





