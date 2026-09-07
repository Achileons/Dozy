//
//  Medication.swift
//  Dozy
//

import Foundation
import SwiftData

@Model
final class Medication {
    var name: String = ""
    var dosage: String = ""
    var notes: String = ""
    /// Hex string (e.g. "#FF5733") used to tint the medication in the UI.
    var colorHex: String = "#4A90E2"
    var createdAt: Date = Date()

    /// Number of units currently left in the package.
    var currentStock: Int = 0
    /// Number of units a full package contains.
    var packageSize: Int = 0
    /// Warn the user once `currentStock` drops to or below this value.
    var lowStockThreshold: Int = 0
    /// Barcode identifier, filled in when the package was scanned.
    var gtin: String?

    @Relationship(deleteRule: .cascade, inverse: \Schedule.medication)
    var schedules: [Schedule]? = []

    @Relationship(deleteRule: .cascade, inverse: \Dose.medication)
    var doses: [Dose]? = []

    init(
        name: String = "",
        dosage: String = "",
        notes: String = "",
        colorHex: String = "#4A90E2",
        createdAt: Date = Date(),
        currentStock: Int = 0,
        packageSize: Int = 0,
        lowStockThreshold: Int = 0,
        gtin: String? = nil,
        schedules: [Schedule]? = [],
        doses: [Dose]? = []
    ) {
        self.name = name
        self.dosage = dosage
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.currentStock = currentStock
        self.packageSize = packageSize
        self.lowStockThreshold = lowStockThreshold
        self.gtin = gtin
        self.schedules = schedules
        self.doses = doses
    }
}
