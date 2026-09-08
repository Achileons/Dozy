//
//  MedicationDatabase.swift
//  Dozy
//

import Foundation
import SQLite3

/// Names a product from its barcode, out of the SQLite file bundled with the app.
///
/// The file is what `Tools/build_medication_database.py` produces: one table with the
/// barcode as its INTEGER PRIMARY KEY, so a lookup is a single b-tree probe. The connection
/// is opened on first use and kept for the life of the app, since opening is the only
/// expensive part.
final class MedicationDatabase {
    static let shared = MedicationDatabase()

    private var connection: OpaquePointer?
    private var lookupStatement: OpaquePointer?
    private var didTryToOpen = false

    private init() {}

    deinit {
        sqlite3_finalize(lookupStatement)
        sqlite3_close(connection)
    }

    // MARK: - Lookup

    /// The product name registered against `barcode`, or `nil` when the code is unknown or
    /// not a barcode at all. Accepts anything `Barcode.normalized` does.
    func lookup(barcode: String) -> String? {
        guard let key = Self.key(for: barcode) else { return nil }
        guard let statement = preparedLookupStatement() else { return nil }
        defer { sqlite3_reset(statement) }

        sqlite3_bind_int64(statement, 1, key)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0)
        else { return nil }

        return String(cString: text)
    }

    /// The integer the table is keyed on, or `nil` when `barcode` cannot become one. The
    /// shaping lives in `Barcode.normalized`; padding only matters for the string form, the
    /// integer is the same either way.
    static func key(for barcode: String) -> Int64? {
        Barcode.normalized(barcode).flatMap { Int64($0) }
    }

    // MARK: - Connection

    /// Opens the database on the first call and hands back the same statement from then on.
    private func preparedLookupStatement() -> OpaquePointer? {
        if let lookupStatement { return lookupStatement }
        guard !didTryToOpen else { return nil }
        didTryToOpen = true

        guard let url = Bundle.main.url(forResource: "medications", withExtension: "db") else {
            assertionFailure("medications.db is missing from the bundle; run Tools/build_medication_database.py")
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return nil
        }
        connection = database

        var statement: OpaquePointer?
        let sql = "SELECT name FROM medications WHERE barcode = ? LIMIT 1"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }
        lookupStatement = statement
        return statement
    }
}
