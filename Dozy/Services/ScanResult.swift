//
//  ScanResult.swift
//  Dozy
//

import Foundation
import Vision

/// What a scan established about the box, whichever code it read.
///
/// The barcode is always there: it is the point of scanning. The other three only travel in
/// a DataMatrix, so a plain linear barcode leaves them `nil`.
struct ScanResult: Equatable {
    /// Thirteen digits, ready for `MedicationDatabase`.
    let barcode: String
    let expiryDate: Date?
    let serialNumber: String?
    let batchNumber: String?
}

/// The shape a barcode takes in the app: a GTIN-13, the code printed on retail packaging.
enum Barcode {
    static let length = 13
    private static let gtin14Length = 14

    /// `raw` as thirteen digits, or `nil` when it cannot be read as a barcode at all.
    ///
    /// Accepts whatever a scanner hands over: a GTIN-14 loses its indicator digit,
    /// separators are dropped, shorter codes are padded — the same shaping the build script
    /// applied to the database, so the two sides meet in the middle.
    static func normalized(_ raw: String) -> String? {
        var digits = raw.filter(\.isNumber)

        // A GTIN-14 is the GTIN-13 behind an indicator digit; on a retail pack the
        // indicator is zero and the rest is the barcode printed beside the 2D code.
        if digits.count == gtin14Length, digits.first == "0" {
            digits.removeFirst()
        }

        guard !digits.isEmpty, digits.count <= length else { return nil }
        return String(repeating: "0", count: length - digits.count) + digits
    }
}

/// Turns a recognised code into a `ScanResult`, by way of whichever reading its symbology
/// calls for.
enum ScanResolver {

    /// `nil` when the payload does not yield a barcode: a DataMatrix that is not GS1, or a
    /// linear code the reader mangled.
    static func resolve(payload: String, symbology: VNBarcodeSymbology) -> ScanResult? {
        switch symbology {
        case .dataMatrix:
            guard let code = DataMatrixParser.parse(payload),
                  let barcode = Barcode.normalized(code.gtin)
            else { return nil }

            return ScanResult(
                barcode: barcode,
                expiryDate: code.expiryDate,
                serialNumber: code.serialNumber,
                batchNumber: code.batchNumber
            )

        case .upce:
            // Vision reports UPC-E either compressed or already widened to UPC-A; widen
            // it ourselves if it is still short.
            let digits = payload.filter(\.isNumber)
            let upca = digits.count == 12 ? digits : expandUPCE(digits)
            return upca.flatMap(Barcode.normalized).map(linear)

        case .ean13, .ean8:
            return Barcode.normalized(payload).map(linear)

        default:
            return nil
        }
    }

    private static func linear(_ barcode: String) -> ScanResult {
        ScanResult(barcode: barcode, expiryDate: nil, serialNumber: nil, batchNumber: nil)
    }

    // MARK: - UPC-E

    /// The twelve digit UPC-A a compressed UPC-E stands for, or `nil` if the digits are not
    /// a UPC-E. Takes the six digit core, or the core with its number system in front, or
    /// that plus the check digit. The check digit is recomputed rather than trusted.
    static func expandUPCE(_ digits: String) -> String? {
        guard digits.allSatisfy(\.isNumber) else { return nil }

        let numberSystem: Character
        let core: Substring
        switch digits.count {
        case 6:
            numberSystem = "0"
            core = Substring(digits)
        case 7, 8:
            numberSystem = digits.first!
            core = digits.dropFirst().prefix(6)
        default:
            return nil
        }
        // UPC-E only compresses number systems 0 and 1.
        guard numberSystem == "0" || numberSystem == "1" else { return nil }

        let d = Array(core)
        let body: String
        switch d[5] {
        case "0", "1", "2":
            body = "\(d[0])\(d[1])\(d[5])0000\(d[2])\(d[3])\(d[4])"
        case "3":
            body = "\(d[0])\(d[1])\(d[2])00000\(d[3])\(d[4])"
        case "4":
            body = "\(d[0])\(d[1])\(d[2])\(d[3])00000\(d[4])"
        default:
            body = "\(d[0])\(d[1])\(d[2])\(d[3])\(d[4])0000\(d[5])"
        }

        let eleven = String(numberSystem) + body
        return eleven + String(gs1CheckDigit(for: eleven))
    }

    /// The GS1 modulo 10 check digit for the digits that precede it.
    private static func gs1CheckDigit(for digits: String) -> Int {
        // Weights alternate 3, 1 counting from the rightmost digit.
        let total = digits.reversed().enumerated().reduce(0) { running, pair in
            let value = pair.element.wholeNumberValue ?? 0
            return running + value * (pair.offset % 2 == 0 ? 3 : 1)
        }
        return (10 - total % 10) % 10
    }
}
