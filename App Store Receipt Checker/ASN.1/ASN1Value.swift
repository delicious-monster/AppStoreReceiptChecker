//
//  ASN1Value.swift
//  Certificate
//
//  Created by William Shipley on 3/12/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation

public struct ASN1Value {
    let universalTag: ASN1Identifier.UniversalTag?
    let bytes: [UInt8]
}



extension ASN1Value { // MARK: calculated values
    public var typedValue: TypedValue {
        guard let universalTag = universalTag else { return .bytes(bytes) }

        switch universalTag {
        case .eof:
            return .bytes(bytes)
        case .boolean:
            guard bytes.count == 1 else { return .bytes(bytes) }
            switch bytes[0] {
            case 0 : return .boolean(false)
            case 255: return .boolean(true)
            default: return .bytes(bytes)
            }
        case .bitString: // FIXME: untested! I didn't have any files with bitStrings in them, so who knows?
            guard bytes.count > 1 else { return .bytes(bytes) }
            let numberOfPaddingBits = Int(bytes[0]) // note first byte contains number of bits to roll entire array of bytes (except first byte) to the right
            let bitCount = bytes.count * 8 - numberOfPaddingBits
            return .bits((0..<bitCount).map {
                return (bytes[$0 / 8] & (0b1000_0000 >> ($0 % 8))) > 0
            })
        case .octetString:
            return .bytes(bytes)
        case .null:
            return .bytes(bytes)
        case .objectID:
            var objectIdentifier: [UInt64] = []
            if bytes.count > 1 {
                objectIdentifier.append(UInt64(bytes[0] / 40)) // magic ASN.1 craziness — first byte is special, holds two tiny ints
                objectIdentifier.append(UInt64(bytes[0] % 40))
                var runningValue: UInt64 = 0
                bytes[1...].forEach { byte in // rest of bytes have high-bit set to continue single int
                    let highBitMask: UInt8 = 0b1000_0000
                    let payloadBits = byte & ~highBitMask
                    runningValue = (runningValue << 7) | UInt64(payloadBits)
                    if (byte & highBitMask) == 0 {
                        objectIdentifier.append(runningValue)
                        runningValue = 0
                    }
                }
            }
            return .objectIdentifer(objectIdentifier)
        case .objectDescriptor:
            return .bytes(bytes)
        case .real:
            return .bytes(bytes)
        case .enumerated:
            return .bytes(bytes)
        case .embeddedPDV:
            return .bytes(bytes)
        case .utf8String:
            return .string(bytes.withUnsafeBytes { String(bytes: $0, encoding: .utf8) ?? "" })
        case .sequence:
            return .bytes(bytes)
        case .set:
            return .bytes(bytes)
        case .numericString:
            return .string(bytes.withUnsafeBytes { String(bytes: $0, encoding: .ascii) ?? "" })
        case .printableString:
            return .string(bytes.withUnsafeBytes { String(bytes: $0, encoding: .ascii) ?? "" })
        case .t61String: // == 8-bit ASCII
        return .string(bytes.withUnsafeBytes { String(bytes: $0, encoding: .utf8) ?? "" })
        case .integer:
            return .integer(bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) })
        case .videotexString:
            return .bytes(bytes)
        case .ia5String: //  == ASCII
            return .string(bytes.withUnsafeBytes { String(bytes: $0, encoding: .ascii) ?? "" })
        case .utcTime:
        // YYMMDDhhmmZ or YYMMDDhhmm+hh'mm' or YYMMDDhhmm-hh'mm' or YYMMDDhhmmssZ or YYMMDDhhmmss+hh'mm' or YYMMDDhhmmss-hh'mm'
            guard let dateString = (bytes.withUnsafeBytes { String(bytes: $0, encoding: .ascii) }) else { return .bytes(bytes) }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyMMddHHmmXX" // see http://userguide.icu-project.org/formatparse/datetime
            if let date = dateFormatter.date(from: dateString) {
                return .date(date)
            }
            dateFormatter.dateFormat = "yyMMddHHmmssXX" // see http://userguide.icu-project.org/formatparse/datetime
            if let date = dateFormatter.date(from: dateString) {
                return .date(date)
            }
            return .bytes(bytes)
        case .generalizedTime:
            return .bytes(bytes)
        case .graphicString:
            return .bytes(bytes)
        case .visibleString:
            return .bytes(bytes)
        case .generalString:
            return .bytes(bytes)
        case .universalString:
            return .bytes(bytes)
        case .bmpString:
            return .bytes(bytes)
        case .highTagNumber:
            return .bytes(bytes)
        }
    }
}


extension ASN1Value { // MARK: types
    public enum TypedValue {
        case boolean(_: Bool)
        case integer(_: UInt64)
        case double(_: Double)
        case string(_: String)
        case objectIdentifer(_: [UInt64])
        case date(_: Date)
        case bits(_: [Bool])
        case bytes(_: [UInt8])
    }
}


extension ASN1Value : CustomDebugStringConvertible { // MARK: <CustomDebugStringConvertible>
    public var debugDescription: String {
        switch typedValue {
        case .boolean(let boolean):
            return "[\(bytes.count)]: \(boolean)"
        case .integer(let integer):
            return "[\(bytes.count)]: \(integer)"
        case .double(let double):
            return "[\(bytes.count)]: \(double)"
        case .string(let string):
            return "[\(bytes.count)]: " + string
        case .objectIdentifer(let objectIdentifier):
            return objectIdentifier.map { "\($0)" }.joined(separator: ".")
        case .date(let date):
            return "[\(bytes.count)]: \(date)"
        case .bits(let bits):
            let maxBits = 40
            let printingBits = bits[0..<min(bits.count, maxBits)]
            let bitsAsString: String = printingBits.map { $0 ? "1" : "0" }.reduce("") { $0 + $1 }
            return "[\(bytes.count)]: " + bitsAsString + ((bits.count > maxBits) ? "…" : "")
        case .bytes(let bytes):
            let maxBytes = 80
            if bytes.count < maxBytes {
                return "[\(bytes.count)]: \(bytes)"
            } else {
                return "[\(bytes.count)]: \(bytes[0..<maxBytes])…"
            }
        }
    }
}
