//
//  CTDatabase.swift
//  CT
//

import Foundation
import SQLite3

/// Single-writer, serialized access to the app's SQLite store. Holds
/// everything: bundled GTFS timetable data (read-only in practice) and the
/// user's own preferences (read/write). See CLAUDE.md's Persistence section.
actor CTDatabase {
    static let shared = CTDatabase()

    private var db: OpaquePointer?

    private init() {}

    // MARK: - Setup

    /// Opens (copying/migrating from the bundled DB if needed) the on-disk
    /// database. Must be called once before any other method.
    func open() throws {
        guard db == nil else { return }
        let destURL = try Self.destinationURL()
        guard let bundledURL = Bundle.main.url(forResource: "BabyBullet", withExtension: "sqlite") else {
            throw DatabaseError.bundledFileMissing
        }

        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: bundledURL, to: destURL)
        } else if try Self.userVersion(at: bundledURL) > (try Self.userVersion(at: destURL)) {
            try Self.migrateTimetableTables(from: bundledURL, into: destURL)
        }

        var handle: OpaquePointer?
        guard sqlite3_open(destURL.path, &handle) == SQLITE_OK, let handle else {
            throw DatabaseError.openFailed
        }
        sqlite3_exec(handle, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        db = handle
    }

    private static func destinationURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return support.appendingPathComponent("BabyBullet.sqlite")
    }

    private static func userVersion(at url: URL) throws -> Int {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle else {
            throw DatabaseError.openFailed
        }
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        sqlite3_prepare_v2(handle, "PRAGMA user_version;", -1, &statement, nil)
        sqlite3_step(statement)
        return Int(sqlite3_column_int(statement, 0))
    }

    /// Replaces the timetable tables in `destURL` with the ones from
    /// `bundledURL`, preserving the existing `preferences` row.
    private static func migrateTimetableTables(from bundledURL: URL, into destURL: URL) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(destURL.path, &handle) == SQLITE_OK, let handle else {
            throw DatabaseError.openFailed
        }
        defer { sqlite3_close(handle) }

        let timetableTables = ["stations", "platforms", "routes", "directions", "calendars", "calendar_dates", "trips", "stop_times"]
        var errMsg: UnsafeMutablePointer<CChar>?
        let newVersion = try userVersion(at: bundledURL)

        sqlite3_exec(handle, "ATTACH DATABASE '\(bundledURL.path)' AS src;", nil, nil, &errMsg)
        sqlite3_exec(handle, "BEGIN TRANSACTION;", nil, nil, &errMsg)
        for table in timetableTables {
            sqlite3_exec(handle, "DELETE FROM \(table);", nil, nil, &errMsg)
            sqlite3_exec(handle, "INSERT INTO \(table) SELECT * FROM src.\(table);", nil, nil, &errMsg)
        }
        sqlite3_exec(handle, "PRAGMA user_version = \(newVersion);", nil, nil, &errMsg)
        sqlite3_exec(handle, "COMMIT;", nil, nil, &errMsg)
        sqlite3_exec(handle, "DETACH DATABASE src;", nil, nil, &errMsg)

        if let errMsg {
            let message = String(cString: errMsg)
            sqlite3_free(errMsg)
            throw DatabaseError.migrationFailed(message)
        }
    }

    // MARK: - Low-level helpers

    private func query<T>(_ sql: String, bind: (OpaquePointer) -> Void = { _ in }, row: (OpaquePointer) -> T) throws -> [T] {
        guard let db else { throw DatabaseError.notOpen }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        bind(statement!)
        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(row(statement!))
        }
        return results
    }

    private func execute(_ sql: String, bind: (OpaquePointer) -> Void = { _ in }) throws {
        guard let db else { throw DatabaseError.notOpen }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        bind(statement!)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func bindText(_ statement: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func columnOptionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL, let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    // MARK: - Stations & platforms

    /// North → south, matching the line's physical trip order (confirmed
    /// against real stop_sequence data — latitude is monotonic along this
    /// corridor, including branch/event stops like Stanford and Broadway).
    func stations() throws -> [Station] {
        try query("SELECT id, name, lat, lon, zone_id FROM stations ORDER BY lat DESC;") { statement in
            Station(
                id: self.columnText(statement, 0), name: self.columnText(statement, 1),
                latitude: sqlite3_column_double(statement, 2), longitude: sqlite3_column_double(statement, 3),
                zoneID: self.columnOptionalText(statement, 4)
            )
        }
    }

    /// Station IDs with at least one stop under any of `serviceIDs` — i.e.
    /// which stations actually run on this schedule (South County stations
    /// like Gilroy are weekday-only; Broadway/Stanford are neither).
    func servedStationIDs(serviceIDs: Set<String>) throws -> Set<String> {
        guard !serviceIDs.isEmpty else { return [] }
        let placeholders = serviceIDs.map { _ in "?" }.joined(separator: ",")
        let serviceIDArray = Array(serviceIDs)
        let sql = """
            SELECT DISTINCT p.station_id
            FROM stop_times st
            JOIN trips t ON t.id = st.trip_id
            JOIN platforms p ON p.id = st.stop_id
            WHERE t.service_id IN (\(placeholders));
            """
        let rows: [String] = try query(
            sql,
            bind: { statement in
                for (offset, serviceID) in serviceIDArray.enumerated() {
                    self.bindText(statement, Int32(1 + offset), serviceID)
                }
            }
        ) { self.columnText($0, 0) }
        return Set(rows)
    }

    func platforms(stationID: String) throws -> [Platform] {
        try query(
            "SELECT id, station_id, name, lat, lon, wheelchair_boarding FROM platforms WHERE station_id = ?;",
            bind: { self.bindText($0, 1, stationID) }
        ) { statement in
            Platform(
                id: self.columnText(statement, 0), stationID: self.columnText(statement, 1), name: self.columnText(statement, 2),
                latitude: sqlite3_column_double(statement, 3), longitude: sqlite3_column_double(statement, 4),
                accessibility: AccessibilityStatus(gtfsValue: Int(sqlite3_column_int(statement, 5)))
            )
        }
    }

    func platform(id: String) throws -> Platform? {
        try query(
            "SELECT id, station_id, name, lat, lon, wheelchair_boarding FROM platforms WHERE id = ?;",
            bind: { self.bindText($0, 1, id) }
        ) { statement in
            Platform(
                id: self.columnText(statement, 0), stationID: self.columnText(statement, 1), name: self.columnText(statement, 2),
                latitude: sqlite3_column_double(statement, 3), longitude: sqlite3_column_double(statement, 4),
                accessibility: AccessibilityStatus(gtfsValue: Int(sqlite3_column_int(statement, 5)))
            )
        }.first
    }

    private func routesByID() throws -> [String: Route] {
        let routes: [Route] = try query("SELECT id, short_name, long_name, color, text_color FROM routes;") { statement in
            Route(
                id: self.columnText(statement, 0), shortName: self.columnText(statement, 1),
                longName: self.columnOptionalText(statement, 2), colorHex: self.columnOptionalText(statement, 3),
                textColorHex: self.columnOptionalText(statement, 4)
            )
        }
        return Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
    }

    // MARK: - Preferences

    func preferences() throws -> Preferences {
        let rows: [Preferences] = try query(
            "SELECT home_station_id, location_enabled, notifications_enabled, onboarding_complete FROM preferences WHERE id = 1;"
        ) { statement in
            Preferences(
                homeStationID: self.columnOptionalText(statement, 0),
                locationEnabled: sqlite3_column_int(statement, 1) != 0,
                notificationsEnabled: sqlite3_column_int(statement, 2) != 0,
                onboardingComplete: sqlite3_column_int(statement, 3) != 0
            )
        }
        guard let prefs = rows.first else { throw DatabaseError.notOpen }
        return prefs
    }

    func setHomeStation(_ stationID: String) throws {
        try execute("UPDATE preferences SET home_station_id = ? WHERE id = 1;") { self.bindText($0, 1, stationID) }
    }

    func setLocationEnabled(_ enabled: Bool) throws {
        try execute("UPDATE preferences SET location_enabled = ? WHERE id = 1;") { sqlite3_bind_int($0, 1, enabled ? 1 : 0) }
    }

    func setNotificationsEnabled(_ enabled: Bool) throws {
        try execute("UPDATE preferences SET notifications_enabled = ? WHERE id = 1;") { sqlite3_bind_int($0, 1, enabled ? 1 : 0) }
    }

    func setOnboardingComplete(_ complete: Bool) throws {
        try execute("UPDATE preferences SET onboarding_complete = ? WHERE id = 1;") { sqlite3_bind_int($0, 1, complete ? 1 : 0) }
    }

    // MARK: - Service calendar

    /// Which `service_id`s run on `date`, per the standard GTFS algorithm:
    /// weekly `calendars` pattern, adjusted by `calendar_dates` exceptions.
    /// `holidayOnlyServiceIDs` are exceptions added for services that have no
    /// weekly pattern at all — one-off modified-schedule days.
    func activeServices(on date: Date) throws -> ActiveServices {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateKey = dateFormatter.string(from: date)
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday

        let calendars: [(serviceID: String, bits: [Bool], start: String, end: String)] = try query(
            "SELECT service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date FROM calendars;"
        ) { statement in
            (
                self.columnText(statement, 0),
                (1...7).map { sqlite3_column_int(statement, $0) != 0 },
                self.columnText(statement, 8), self.columnText(statement, 9)
            )
        }
        // GTFS column order is Mon..Sun; Foundation's `.weekday` is Sun=1..Sat=7.
        let mondayIndexedWeekday = (weekday + 5) % 7 // Sun->6, Mon->0, ... Sat->5

        var regular = Set(calendars.filter { entry in
            entry.bits[mondayIndexedWeekday] && entry.start <= dateKey && dateKey <= entry.end
        }.map(\.serviceID))
        let calendarServiceIDs = Set(calendars.map(\.serviceID))

        let exceptions: [(serviceID: String, type: Int)] = try query(
            "SELECT service_id, exception_type FROM calendar_dates WHERE date = ?;",
            bind: { self.bindText($0, 1, dateKey) }
        ) { statement in
            (self.columnText(statement, 0), Int(sqlite3_column_int(statement, 1)))
        }
        var holidayOnly: Set<String> = []
        for exception in exceptions {
            if exception.type == 2 {
                regular.remove(exception.serviceID)
            } else if exception.type == 1 {
                regular.insert(exception.serviceID)
                if !calendarServiceIDs.contains(exception.serviceID) {
                    holidayOnly.insert(exception.serviceID)
                }
            }
        }
        return ActiveServices(serviceIDs: regular, holidayOnlyServiceIDs: holidayOnly)
    }

    func calendarDescription(for serviceID: String) throws -> String? {
        let rows: [String?] = try query(
            "SELECT description FROM calendars WHERE service_id = ?;",
            bind: { self.bindText($0, 1, serviceID) }
        ) { self.columnOptionalText($0, 0) }
        return rows.first ?? nil
    }

    func weekdayServiceIDs() throws -> Set<String> {
        let rows: [String] = try query("SELECT service_id FROM calendars WHERE monday = 1;") { self.columnText($0, 0) }
        return Set(rows)
    }

    func weekendServiceIDs() throws -> Set<String> {
        let rows: [String] = try query("SELECT service_id FROM calendars WHERE saturday = 1 AND monday = 0;") { self.columnText($0, 0) }
        return Set(rows)
    }

    // MARK: - Departures & trip search

    /// Each trip's arrival time at its final stop (its terminus) — used to
    /// show ride duration when no destination has been chosen.
    private func tripTerminusArrivalTimes() throws -> [String: ServiceTime] {
        let sql = """
            SELECT st.trip_id, st.arrival_time
            FROM stop_times st
            JOIN (SELECT trip_id, MAX(stop_sequence) AS max_seq FROM stop_times GROUP BY trip_id) last
              ON last.trip_id = st.trip_id AND last.max_seq = st.stop_sequence;
            """
        let rows: [(tripID: String, timeString: String)] = try query(sql) { statement in
            (self.columnText(statement, 0), self.columnText(statement, 1))
        }
        var result: [String: ServiceTime] = [:]
        for row in rows {
            guard let time = ServiceTime(gtfsString: row.timeString) else { continue }
            result[row.tripID] = time
        }
        return result
    }

    func departures(fromStationID stationID: String, serviceIDs: Set<String>, after time: ServiceTime) throws -> [Departure] {
        guard !serviceIDs.isEmpty else { return [] }
        let routes = try routesByID()
        let termini = try tripTerminusArrivalTimes()
        let placeholders = serviceIDs.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT t.id, t.route_id, t.short_name, t.headsign, st.departure_time
            FROM stop_times st
            JOIN trips t ON t.id = st.trip_id
            JOIN platforms p ON p.id = st.stop_id
            WHERE p.station_id = ? AND st.pickup_type = 0 AND t.service_id IN (\(placeholders));
            """
        let serviceIDArray = Array(serviceIDs)
        let rows: [(tripID: String, routeID: String, shortName: String?, headsign: String?, timeString: String)] = try query(
            sql,
            bind: { statement in
                self.bindText(statement, 1, stationID)
                for (offset, serviceID) in serviceIDArray.enumerated() {
                    self.bindText(statement, Int32(2 + offset), serviceID)
                }
            }
        ) { statement in
            (
                self.columnText(statement, 0), self.columnText(statement, 1),
                self.columnOptionalText(statement, 2), self.columnOptionalText(statement, 3),
                self.columnText(statement, 4)
            )
        }

        let departures = rows.compactMap { row -> Departure? in
            guard let serviceTime = ServiceTime(gtfsString: row.timeString), let route = routes[row.routeID],
                  let terminusArrival = termini[row.tripID]
            else { return nil }
            return Departure(
                tripID: row.tripID, trainNumber: row.shortName ?? row.tripID, trainType: route.trainType,
                departureTime: serviceTime, destination: row.headsign ?? "", terminusArrivalTime: terminusArrival
            )
        }
        return departures
            .filter { $0.departureTime >= time }
            .sorted { $0.departureTime < $1.departureTime }
    }

    func tripResults(originStationID: String, destinationStationID: String, serviceIDs: Set<String>) throws -> [TripResult] {
        guard !serviceIDs.isEmpty else { return [] }
        let routes = try routesByID()
        let placeholders = serviceIDs.map { _ in "?" }.joined(separator: ",")
        let serviceIDArray = Array(serviceIDs)

        func stopTimes(stationID: String) throws -> [String: (sequence: Int, time: ServiceTime)] {
            let sql = """
                SELECT t.id, st.stop_sequence, st.departure_time
                FROM stop_times st
                JOIN trips t ON t.id = st.trip_id
                JOIN platforms p ON p.id = st.stop_id
                WHERE p.station_id = ? AND t.service_id IN (\(placeholders));
                """
            let rows: [(tripID: String, sequence: Int, timeString: String)] = try query(
                sql,
                bind: { statement in
                    self.bindText(statement, 1, stationID)
                    for (offset, serviceID) in serviceIDArray.enumerated() {
                        self.bindText(statement, Int32(2 + offset), serviceID)
                    }
                }
            ) { statement in
                (self.columnText(statement, 0), Int(sqlite3_column_int(statement, 1)), self.columnText(statement, 2))
            }
            var result: [String: (sequence: Int, time: ServiceTime)] = [:]
            for row in rows {
                guard let time = ServiceTime(gtfsString: row.timeString) else { continue }
                result[row.tripID] = (row.sequence, time)
            }
            return result
        }

        let originStops = try stopTimes(stationID: originStationID)
        let destinationStops = try stopTimes(stationID: destinationStationID)

        let tripInfo: [Trip] = try query(
            "SELECT id, route_id, service_id, headsign, direction_id, short_name, bikes_allowed, wheelchair_accessible FROM trips WHERE service_id IN (\(placeholders));",
            bind: { statement in
                for (offset, serviceID) in serviceIDArray.enumerated() {
                    self.bindText(statement, Int32(1 + offset), serviceID)
                }
            }
        ) { statement in
            Trip(
                id: self.columnText(statement, 0), routeID: self.columnText(statement, 1), serviceID: self.columnText(statement, 2),
                headsign: self.columnOptionalText(statement, 3), directionID: Int(sqlite3_column_int(statement, 4)),
                shortName: self.columnOptionalText(statement, 5),
                bikesAllowed: AccessibilityStatus(gtfsValue: Int(sqlite3_column_int(statement, 6))),
                wheelchairAccessible: AccessibilityStatus(gtfsValue: Int(sqlite3_column_int(statement, 7)))
            )
        }
        let tripsByID = Dictionary(uniqueKeysWithValues: tripInfo.map { ($0.id, $0) })

        var results: [TripResult] = []
        for (tripID, origin) in originStops {
            guard let destination = destinationStops[tripID], destination.sequence > origin.sequence,
                  let trip = tripsByID[tripID], let route = routes[trip.routeID]
            else { continue }
            let stops = try stopsForTrip(tripID: tripID, fromSequence: origin.sequence, toSequence: destination.sequence)
            results.append(TripResult(
                tripID: tripID, trainNumber: trip.shortName ?? tripID, trainType: route.trainType,
                departureTime: origin.time, arrivalTime: destination.time, stops: stops
            ))
        }
        return results.sorted { $0.departureTime < $1.departureTime }
    }

    func stopsForTrip(tripID: String, fromSequence: Int = 0, toSequence: Int = Int.max) throws -> [StopArrival] {
        let sql = """
            SELECT s.name, st.stop_id, st.departure_time, st.stop_sequence, st.stop_headsign
            FROM stop_times st
            JOIN platforms p ON p.id = st.stop_id
            JOIN stations s ON s.id = p.station_id
            WHERE st.trip_id = ? AND st.stop_sequence >= ? AND st.stop_sequence <= ?
            ORDER BY st.stop_sequence ASC;
            """
        return try query(
            sql,
            bind: { statement in
                self.bindText(statement, 1, tripID)
                sqlite3_bind_int(statement, 2, Int32(fromSequence))
                sqlite3_bind_int(statement, 3, toSequence >= Int(Int32.max) ? Int32.max : Int32(toSequence))
            }
        ) { statement in
            StopArrival(
                stationName: self.columnText(statement, 0),
                stopID: self.columnText(statement, 1),
                time: ServiceTime(gtfsString: self.columnText(statement, 2)) ?? ServiceTime(secondsSinceMidnight: 0),
                stopSequence: Int(sqlite3_column_int(statement, 3)),
                headsign: self.columnOptionalText(statement, 4)
            )
        }
    }
}

nonisolated struct ActiveServices: Sendable {
    let serviceIDs: Set<String>
    let holidayOnlyServiceIDs: Set<String>

    var isHoliday: Bool { !holidayOnlyServiceIDs.isEmpty }
}

nonisolated enum DatabaseError: Error {
    case bundledFileMissing
    case openFailed
    case notOpen
    case queryFailed(String)
    case migrationFailed(String)
}
