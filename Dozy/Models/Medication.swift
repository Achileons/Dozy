//
//  Medication.swift
//  Dozy
//

import Foundation
import SwiftData

/// The forms a medication comes in. The raw value is what gets stored, so renaming a case
/// would orphan existing records.
enum DosageUnit: String, CaseIterable, Identifiable {
    case tablet
    case capsule
    case drop
    case syrup
    case injection
    case sachet

    var id: String { rawValue }

    /// The label on the picker button.
    var title: String {
        switch self {
        case .tablet: "Tablet"
        case .capsule: "Kapsül"
        case .drop: "Damla"
        case .syrup: "Şurup"
        case .injection: "İğne"
        case .sachet: "Şase"
        }
    }

    /// The word that follows the amount. Syrup is measured rather than counted, so it reads
    /// as a volume instead of as a number of syrups.
    var suffix: String {
        switch self {
        case .tablet: "tablet"
        case .capsule: "kapsül"
        case .drop: "damla"
        case .syrup: "ml"
        case .injection: "iğne"
        case .sachet: "şase"
        }
    }
}

@Model
final class Medication {
    var name: String = ""
    /// The finished line shown in the UI, e.g. "1 tablet". Built from the two fields below,
    /// which are kept alongside it so the form can restore the exact selection.
    var dosage: String = ""
    var dosageUnit: String = DosageUnit.tablet.rawValue
    var dosageAmount: Double = 1
    var notes: String = ""
    /// Hex string (e.g. "#FF5733") used to tint the medication in the UI.
    var colorHex: String = "#4A90E2"
    var createdAt: Date = Date()

    /// A medication the user removed. It stays in the store so the doses already recorded
    /// against it keep their name, colour and dosage in the calendar.
    var isArchived: Bool = false
    var archivedAt: Date?

    /// Whether this medication counts what is left in the package. Off unless the user
    /// turns it on, so the three fields below stay at zero and out of the way.
    var stockEnabled: Bool = false
    /// Number of units currently left in the package.
    var currentStock: Int = 0
    /// Number of units a full package contains.
    var packageSize: Int = 0
    /// Warn the user once `currentStock` drops to or below this value.
    var lowStockThreshold: Int = 0
    /// Barcode identifier, filled in when the package was scanned.
    var gtin: String?
    /// Identifier of the pending low stock warning, so it can be withdrawn once the package
    /// is refilled. Empty when no warning is scheduled.
    var lowStockNotificationID: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Schedule.medication)
    var schedules: [Schedule]? = []

    @Relationship(deleteRule: .cascade, inverse: \Dose.medication)
    var doses: [Dose]? = []

    init(
        name: String = "",
        dosage: String = "",
        dosageUnit: String = DosageUnit.tablet.rawValue,
        dosageAmount: Double = 1,
        notes: String = "",
        colorHex: String = "#4A90E2",
        createdAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        stockEnabled: Bool = false,
        currentStock: Int = 0,
        packageSize: Int = 0,
        lowStockThreshold: Int = 0,
        gtin: String? = nil,
        lowStockNotificationID: String = "",
        schedules: [Schedule]? = [],
        doses: [Dose]? = []
    ) {
        self.name = name
        self.dosage = dosage
        self.dosageUnit = dosageUnit
        self.dosageAmount = dosageAmount
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.stockEnabled = stockEnabled
        self.currentStock = currentStock
        self.packageSize = packageSize
        self.lowStockThreshold = lowStockThreshold
        self.gtin = gtin
        self.lowStockNotificationID = lowStockNotificationID
        self.schedules = schedules
        self.doses = doses
    }
}

extension Medication {
    /// The stored unit read back as a case, falling back to the default for a value written
    /// by a version that knew a unit this one does not.
    var unit: DosageUnit {
        DosageUnit(rawValue: dosageUnit) ?? .tablet
    }

    /// What is left in the package, worded with the medication's own unit: "12 tablet".
    var stockText: String {
        Self.dosageText(amount: Double(currentStock), unit: unit)
    }

    /// Whether the package has run down far enough to warn about.
    var isLowOnStock: Bool {
        stockEnabled && currentStock <= lowStockThreshold
    }

    /// Joins the amount and the unit into the line stored in `dosage`.
    static func dosageText(amount: Double, unit: DosageUnit) -> String {
        let formatted = amount.formatted(
            .number.precision(.fractionLength(0...1)).locale(.turkish)
        )
        return "\(formatted) \(unit.suffix)"
    }
}
