import Foundation
import Security

struct SupabaseConfiguration {
    let projectURL: URL
    let anonKey: String
    let functionName: String

    static let moonPlace = SupabaseConfiguration(
        projectURL: URL(string: "https://gurxeufdkvdhlvejyrhj.supabase.co")!,
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1cnhldWZka3ZkaGx2ZWp5cmhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MzM4MDcsImV4cCI6MjEwNDMwOTgwN30.u0m_ngG_MgdSjsc1JIQw_YOtuSgG6gm8Znab_EUhcxw",
        functionName: "moon-auth"
    )
}

protocol MoonPlaceAuthenticationClient {
    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult
    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult
}

struct MoonPlaceAuthenticationResult {
    let username: String
    let phone: String
    let expiresAt: Date?
}

/// Aggregated backend protocol implemented by both the Supabase client and the
/// Firebase client, so the Moon Place auth store can use either provider.
protocol MoonPlaceSessionBackend {
    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult
    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult
    func cachedProfile() -> MoonPlaceStoredProfile?
    func restoreSession() async -> MoonPlaceAuthenticationResult?
    func signOut(username: String)
}

struct MoonPlaceStoredProfile: Codable {
    let username: String
    let phone: String
    let expiresAt: Date?
}

enum SupabaseAuthenticationError: LocalizedError {
    case endpointNotConfigured
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .endpointNotConfigured:
            return "Supabase project URL or anon key is not configured."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

final class SupabaseAuthenticationClient: MoonPlaceAuthenticationClient, MoonPlaceSessionBackend {
    private let configuration: SupabaseConfiguration

    private static let sessionProfileKey = "moon.place.session.v1"
    private static let accessTokenService = "moon.place.access-token"
    private static let refreshTokenService = "moon.place.refresh-token"

    init(configuration: SupabaseConfiguration = .moonPlace) {
        self.configuration = configuration
    }

    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult {
        try await request(action: "login", username: username, password: password, key: key, phone: "")
    }

    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult {
        try await request(action: "register", username: username, password: password, key: key, phone: phone)
    }

    // MARK: Session

    var isConfigured: Bool {
        !configuration.projectURL.absoluteString.contains("YOUR_PROJECT_REF")
            && !configuration.anonKey.contains("YOUR_SUPABASE_ANON_KEY")
    }

    func validateLicenseKey(key: String, deviceID: String) async throws -> Date? {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDeviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isConfigured else {
            throw SupabaseAuthenticationError.endpointNotConfigured
        }
        guard configuration.projectURL.scheme == "https" else {
            throw SupabaseAuthenticationError.server("La conexión de licencias debe usar HTTPS.")
        }
        guard !cleanKey.isEmpty, !cleanDeviceID.isEmpty else {
            throw SupabaseAuthenticationError.server("Pega una key válida para continuar.")
        }

        let endpoint = configuration.projectURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent(configuration.functionName)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": "validate-key",
            "key": cleanKey,
            "device_id": cleanDeviceID
        ])

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAuthenticationError.server(
                object?["message"] as? String ?? "No se pudo validar la key."
            )
        }
        guard let object, object["valid"] as? Bool == true else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        if let expiresText = object["expires_at"] as? String {
            guard let expiresAt = Self.parseISODate(expiresText) else {
                throw SupabaseAuthenticationError.invalidResponse
            }
            return expiresAt
        }
        guard object["permanent"] as? Bool == true else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        return nil
    }

    func cachedProfile() -> MoonPlaceStoredProfile? {
        loadProfile()
    }

    /// Restores a stored session: returns the profile while an unexpired access
    /// token exists, attempts a refresh otherwise, and clears the session when it
    /// can no longer be restored.
    func restoreSession() async -> MoonPlaceAuthenticationResult? {
        guard let profile = loadProfile() else { return nil }
        if let expiresAt = profile.expiresAt, expiresAt <= Date() {
            clearSession(username: profile.username)
            return nil
        }
        if let accessToken = KeychainTokenStore.load(service: Self.accessTokenService, account: profile.username),
           !isExpired(jwt: accessToken) {
            return MoonPlaceAuthenticationResult(
                username: profile.username,
                phone: profile.phone,
                expiresAt: profile.expiresAt
            )
        }
        guard let refreshToken = KeychainTokenStore.load(service: Self.refreshTokenService, account: profile.username) else {
            clearSession(username: profile.username)
            return nil
        }
        do {
            try await refreshAccessToken(refreshToken: refreshToken, username: profile.username)
            return MoonPlaceAuthenticationResult(
                username: profile.username,
                phone: profile.phone,
                expiresAt: profile.expiresAt
            )
        } catch {
            if case SupabaseAuthenticationError.server = error {
                clearSession(username: profile.username)
            }
            return nil
        }
    }

    func signOut(username: String) {
        clearSession(username: username)
    }

    // MARK: Refresh

    private func refreshAccessToken(refreshToken: String, username: String) async throws {
        guard var components = URLComponents(
            url: configuration.projectURL.appendingPathComponent("auth/v1/token"),
            resolvingAgainstBaseURL: false
        ) else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let endpoint = components.url else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAuthenticationError.server(
                object?["error_description"] as? String
                    ?? object?["message"] as? String
                    ?? "Session refresh failed."
            )
        }
        guard let object,
              let accessToken = object["access_token"] as? String,
              let refreshedRefreshToken = object["refresh_token"] as? String else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        KeychainTokenStore.save(accessToken, service: Self.accessTokenService, account: username)
        KeychainTokenStore.save(refreshedRefreshToken, service: Self.refreshTokenService, account: username)
    }

    // MARK: Request

    private func request(
        action: String,
        username: String,
        password: String,
        key: String,
        phone: String
    ) async throws -> MoonPlaceAuthenticationResult {
        guard !configuration.projectURL.absoluteString.contains("YOUR_PROJECT_REF"),
              !configuration.anonKey.contains("YOUR_SUPABASE_ANON_KEY") else {
            throw SupabaseAuthenticationError.endpointNotConfigured
        }
        guard configuration.projectURL.scheme == "https" else {
            throw SupabaseAuthenticationError.server(
                "The Supabase project URL must use https:// (current value: \(configuration.projectURL.absoluteString))."
            )
        }
        let endpoint = configuration.projectURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent(configuration.functionName)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": action,
            "username": username,
            "password": password,
            "key": key,
            "phone": phone
        ])

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAuthenticationError.server(object?["message"] as? String ?? "Authentication failed.")
        }
        guard let object,
              let returnedUsername = object["username"] as? String,
              let returnedPhone = object["phone"] as? String,
              let expiresText = object["expires_at"] as? String,
              let expiresAt = Self.parseISODate(expiresText) else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        if let accessToken = object["access_token"] as? String,
           let refreshToken = object["refresh_token"] as? String {
            KeychainTokenStore.save(accessToken, service: Self.accessTokenService, account: returnedUsername)
            KeychainTokenStore.save(refreshToken, service: Self.refreshTokenService, account: returnedUsername)
            saveProfile(username: returnedUsername, phone: returnedPhone, expiresAt: expiresAt)
        }
        return MoonPlaceAuthenticationResult(
            username: returnedUsername,
            phone: returnedPhone,
            expiresAt: expiresAt
        )
    }

    // MARK: Transport

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            let host = request.url?.host ?? "unknown"
            log("moon-auth: transport error \(error.code.rawValue) — \(error.localizedDescription) (\(host))")
            switch error.code {
            case .secureConnectionFailed:
                throw SupabaseAuthenticationError.server(
                    "Secure connection to \(host) failed (TLS). Verify the project URL is exactly https://<project-ref>.supabase.co and try again on another network (Wi-Fi/cellular)."
                )
            case .appTransportSecurityRequiresSecureConnection:
                throw SupabaseAuthenticationError.server(
                    "The connection to \(host) was blocked: the project URL must use https://."
                )
            case .cannotFindHost, .dnsLookupFailed:
                throw SupabaseAuthenticationError.server(
                    "The host \(host) could not be found. Check the project ref in the URL."
                )
            case .notConnectedToInternet:
                throw SupabaseAuthenticationError.server(
                    "There is no Internet connection."
                )
            case .timedOut:
                throw SupabaseAuthenticationError.server(
                    "The connection to \(host) timed out. Try again."
                )
            default:
                throw SupabaseAuthenticationError.server(
                    "Could not connect to \(host): \(error.localizedDescription)."
                )
            }
        } catch {
            throw error
        }
    }

    // MARK: Profile

    private func saveProfile(username: String, phone: String, expiresAt: Date?) {
        let profile = MoonPlaceStoredProfile(username: username, phone: phone, expiresAt: expiresAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.sessionProfileKey)
    }

    private func loadProfile() -> MoonPlaceStoredProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionProfileKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MoonPlaceStoredProfile.self, from: data)
    }

    private func clearSession(username: String) {
        KeychainTokenStore.delete(service: Self.accessTokenService, account: username)
        KeychainTokenStore.delete(service: Self.refreshTokenService, account: username)
        UserDefaults.standard.removeObject(forKey: Self.sessionProfileKey)
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

    private static func parseISODate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }
}

private enum KeychainTokenStore {
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
