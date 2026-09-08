//
//  DataMatrixParser.swift
//  Dozy
//

import Foundation

/// What the 2D code on a medicine box says about it.
struct ScannedCode: Equatable {
    /// Fourteen digits, as printed in the code. Pass it through `MedicationDatabase` to get
    /// the retail barcode behind it.
    let gtin: String
    let serialNumber: String?
    let expiryDate: Date?
    let batchNumber: String?
}

/// Reads the GS1 element string a pharmaceutical DataMatrix carries.
///
/// The payload is a run of application identifiers, each followed by its value:
/// `01` the GTIN, `17` the expiry date, `21` the serial number and `10` the batch. The first
/// two are fixed width; the other two run until a group separator (ASCII 29) or the end of
/// the string. Some scanners drop the separator, so a variable field is also allowed to end
/// where a not yet seen identifier begins — that is ambiguous, and settled by trying the
/// shortest reading that lets the remainder parse. Identifiers may come in any order.
enum DataMatrixParser {

    static func parse(_ payload: String) -> ScannedCode? {
        var text = Substring(payload)

        // A symbology identifier some readers prefix, and a leading FNC1.
        if text.hasPrefix(symbologyIdentifier) {
            text = text.dropFirst(symbologyIdentifier.count)
        }
        text = text.drop { $0 == groupSeparator }

        guard let fields = parse(text, collected: [:]),
              let gtin = fields[.gtin]
        else { return nil }

        return ScannedCode(
            gtin: gtin,
            serialNumber: fields[.serialNumber],
            expiryDate: fields[.expiry].flatMap(expiryDate(from:)),
            batchNumber: fields[.batch]
        )
    }

    // MARK: - Element string

    private enum Identifier: String, CaseIterable {
        case gtin = "01"
        case expiry = "17"
        case serialNumber = "21"
        case batch = "10"

        /// The value width, or `nil` for a field that runs to a separator.
        var fixedLength: Int? {
            switch self {
            case .gtin: 14
            case .expiry: 6
            case .serialNumber, .batch: nil
            }
        }

        /// GS1 caps both variable fields at twenty characters.
        static let maximumVariableLength = 20
    }

    private static let symbologyIdentifier = "]d2"
    private static let groupSeparator: Character = "\u{1D}"

    /// Consumes identifiers from the front of `text` until nothing is left, backtracking
    /// through the possible ends of a variable field when no separator marks it.
    private static func parse(
        _ text: Substring,
        collected: [Identifier: String]
    ) -> [Identifier: String]? {
        let text = text.drop { $0 == groupSeparator }
        guard !text.isEmpty else { return collected }

        guard let identifier = Identifier(rawValue: String(text.prefix(2))),
              collected[identifier] == nil
        else { return nil }
        let body = text.dropFirst(2)

        if let length = identifier.fixedLength {
            guard body.count >= length else { return nil }
            let value = body.prefix(length)
            guard value.allSatisfy(\.isNumber) else { return nil }

            var next = collected
            next[identifier] = String(value)
            return parse(body.dropFirst(length), collected: next)
        }

        // A separator, when present, is the end of the field and nothing else is tried.
        if let separator = body.firstIndex(of: groupSeparator) {
            let value = body[..<separator]
            guard !value.isEmpty, value.count <= Identifier.maximumVariableLength else { return nil }

            var next = collected
            next[identifier] = String(value)
            return parse(body[separator...], collected: next)
        }

        // No separator: the field ends where the string does, or where another identifier
        // starts. Shortest first, so a serial that happens to contain "10" is only split
        // there if the rest still makes sense as fields.
        guard !body.isEmpty else { return nil }
        for length in 1...min(body.count, Identifier.maximumVariableLength) {
            let end = body.index(body.startIndex, offsetBy: length)
            let rest = body[end...]

            let restLooksLikeField = rest.isEmpty
                || Identifier(rawValue: String(rest.prefix(2))).map { collected[$0] == nil && $0 != identifier } == true
            guard restLooksLikeField else { continue }

            var next = collected
            next[identifier] = String(body[..<end])
            if let parsed = parse(rest, collected: next) {
                return parsed
            }
        }

        return nil
    }

    // MARK: - Expiry

    /// `YYMMDD`, where a day of `00` means the last day of the month, as GS1 allows.
    private static func expiryDate(from value: String) -> Date? {
        guard value.count == 6,
              let year = Int(value.prefix(2)),
              let month = Int(value.dropFirst(2).prefix(2)),
              let day = Int(value.suffix(2)),
              (1...12).contains(month)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var components = DateComponents(year: 2000 + year, month: month, day: max(day, 1))
        guard let date = calendar.date(from: components) else { return nil }
        guard day == 0 else { return date }

        // Roll forward a month and back a day to land on the month's last day.
        components.month = month + 1
        components.day = 0
        return calendar.date(from: components)
    }
}
