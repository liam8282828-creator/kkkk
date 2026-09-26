import Foundation
import UIKit

/// Validates a Moon Place license key against the Firebase Firestore database.
/// This file is the only addition made to the original project for key-based access control.
enum MoonKeyValidator {

    // MARK: - Configuration

    private static let firestoreBase = "https://firestore.googleapis.com/v1/projects/keyoutsystem-358ef/databases/(default)/documents"
    private static let firebaseApiKey = "AIzaSyADR8MgW6mknGWDBlZYXO3QpdNLAQDeiDY"

    // MARK: - Error

    enum KeyError: LocalizedError {
        case notFound
        case banned
        case expired
        case wrongDevice
        case networkError
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notFound:        return "License key not found. Check the key and try again."
            case .banned:          return "This license key has been banned."
            case .expired:         return "Your license key has expired."
            case .wrongDevice:     return "This key is registered on another device."
            case .networkError:    return "Could not connect to the license server."
            case .invalidResponse: return "Unexpected response from the license server."
            }
        }
    }

    // MARK: - Device ID

    static func deviceHWID() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_DEVICE"
    }

    // MARK: - Validation

    /// Validates the key and binds the HWID if this is the first activation.
    static func validate(key: String, hwid: String) async throws -> Date? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeyError.notFound }

        // Query Firestore for the key
        let url = URL(string: "\(firestoreBase):runQuery?key=\(firebaseApiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "keys"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "key"],
                        "op": "EQUAL",
                        "value": ["stringValue": trimmed]
                    ]
                ],
                "limit": 1
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw KeyError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw KeyError.networkError
        }

        guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let hit = results.first(where: { $0["document"] != nil }),
              let doc = hit["document"] as? [String: Any],
              let docName = doc["name"] as? String,
              let fields = doc["fields"] as? [String: Any] else {
            throw KeyError.notFound
        }

        // Check status
        if let statusField = fields["status"] as? [String: Any],
           let status = statusField["stringValue"] as? String,
           status == "banned" {
            throw KeyError.banned
        }

        // Check expiration
        var expirationDate: Date? = nil
        if let expField = fields["expires_at"] as? [String: Any],
           let expStr = expField["timestampValue"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expirationDate = formatter.date(from: expStr)
            if expirationDate == nil {
                expirationDate = ISO8601DateFormatter().date(from: expStr)
            }
            if let expDate = expirationDate, expDate < Date() {
                throw KeyError.expired
            }
        }

        // Check / bind HWID
        let currentHWID: String? = {
            guard let field = fields["hwid"] as? [String: Any],
                  let val = field["stringValue"] as? String,
                  !val.isEmpty else { return nil }
            return val
        }()

        if let currentHWID = currentHWID {
            if currentHWID != hwid { throw KeyError.wrongDevice }
        } else {
            // First activation - bind HWID
            try await bindHWID(documentName: docName, hwid: hwid)
        }
        
        return expirationDate
    }

    // MARK: - HWID Binding

    private static func bindHWID(documentName: String, hwid: String) async throws {
        let urlString = "https://firestore.googleapis.com/v1/\(documentName)?updateMask.fieldPaths=hwid&key=\(firebaseApiKey)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "fields": ["hwid": ["stringValue": hwid]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            // Non-fatal: allow login even if bind fails
            return
        }
    }
}


