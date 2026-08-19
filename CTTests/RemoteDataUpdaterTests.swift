//
//  RemoteDataUpdaterTests.swift
//  CTTests
//

import Testing
@testable import CT
import Foundation

struct RemoteDataUpdaterTests {

    @Test func decodesManifest() throws {
        let json = """
            {
              "schema_version": 1,
              "data_version": 7,
              "sqlite_url": "https://github.com/spaquet/Baby-Bullet/releases/download/data-v7/BabyBullet.sqlite",
              "sha256": "abc123",
              "published_at": "2026-08-19T00:00:00Z"
            }
            """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: json)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.dataVersion == 7)
        #expect(manifest.sqliteURL == "https://github.com/spaquet/Baby-Bullet/releases/download/data-v7/BabyBullet.sqlite")
        #expect(manifest.sha256 == "abc123")
    }

    @Test func newerDataVersionTriggersUpdate() {
        let manifest = ReleaseManifest(schemaVersion: 1, dataVersion: 7, sqliteURL: "https://example.com/db.sqlite", sha256: "x", publishedAt: "2026-08-19T00:00:00Z")
        #expect(manifest.dataVersion > 6)
        #expect(!(manifest.dataVersion > 7))
    }

    @Test func schemaMismatchIsDetectable() {
        let manifest = ReleaseManifest(schemaVersion: 2, dataVersion: 7, sqliteURL: "https://example.com/db.sqlite", sha256: "x", publishedAt: "2026-08-19T00:00:00Z")
        #expect(manifest.schemaVersion != CTDatabase.expectedSchemaVersion)
    }
}
