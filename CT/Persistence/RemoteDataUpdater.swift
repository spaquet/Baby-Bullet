//
//  RemoteDataUpdater.swift
//  CT
//

import CryptoKit
import Foundation

/// Refreshes GTFS timetable/holiday data from a GitHub Release without an
/// App Store update, by pulling down an updated `BabyBullet.sqlite` and
/// handing it to `CTDatabase`. See docs/REMOTE_DATA_UPDATES.md for the full
/// design — this is a distinct concern from storage (networking), so it
/// sits next to `CTDatabase` rather than inside it.
actor RemoteDataUpdater {
    static let shared = RemoteDataUpdater()

    private static let manifestURL = URL(string: "https://github.com/spaquet/Baby-Bullet/releases/latest/download/latest.json")!
    private static let checkInterval: TimeInterval = 86_400 // 1 day
    private static let lastCheckDefaultsKey = "RemoteDataUpdater.lastCheckedAt"

    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    /// Call once at launch, after `CTDatabase.open()`. Fire-and-forget from
    /// the caller's perspective — failures are silent, bundled/cached data
    /// is always a valid fallback.
    func checkForUpdateIfDue() async {
        guard shouldCheck() else { return }
        do {
            let manifest = try await fetchManifest()
            guard manifest.schemaVersion == CTDatabase.expectedSchemaVersion else {
                recordCheckTimestamp()
                return
            }
            let currentDataVersion = try await CTDatabase.shared.dataVersion()
            guard manifest.dataVersion > currentDataVersion else {
                recordCheckTimestamp()
                return
            }
            let tempURL = try await download(manifest)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            try verify(tempURL, sha256: manifest.sha256)
            try await CTDatabase.shared.applyRemoteTimetable(from: tempURL, dataVersion: manifest.dataVersion)
            recordCheckTimestamp()
        } catch {
            // Network/parse/verify failure: keep existing data, try again next interval.
        }
    }

    private func shouldCheck() -> Bool {
        guard let lastChecked = UserDefaults.standard.object(forKey: Self.lastCheckDefaultsKey) as? Date else { return true }
        return Date.now.timeIntervalSince(lastChecked) >= Self.checkInterval
    }

    private func recordCheckTimestamp() {
        UserDefaults.standard.set(Date.now, forKey: Self.lastCheckDefaultsKey)
    }

    private func fetchManifest() async throws -> ReleaseManifest {
        let (data, response) = try await session.data(from: Self.manifestURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RemoteDataUpdaterError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(ReleaseManifest.self, from: data)
    }

    private func download(_ manifest: ReleaseManifest) async throws -> URL {
        guard let sqliteURL = URL(string: manifest.sqliteURL) else { throw RemoteDataUpdaterError.invalidURL }
        let (tempFileURL, response) = try await session.download(from: sqliteURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempFileURL)
            throw RemoteDataUpdaterError.httpStatus(http.statusCode)
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        try FileManager.default.moveItem(at: tempFileURL, to: destination)
        return destination
    }

    private func verify(_ url: URL, sha256 expected: String) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(expected) == .orderedSame else {
            throw RemoteDataUpdaterError.checksumMismatch
        }
    }
}

struct ReleaseManifest: Decodable, Sendable {
    let schemaVersion: Int
    let dataVersion: Int
    let sqliteURL: String
    let sha256: String
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case dataVersion = "data_version"
        case sqliteURL = "sqlite_url"
        case sha256
        case publishedAt = "published_at"
    }
}

nonisolated enum RemoteDataUpdaterError: Error {
    case invalidURL
    case httpStatus(Int)
    case checksumMismatch
}
