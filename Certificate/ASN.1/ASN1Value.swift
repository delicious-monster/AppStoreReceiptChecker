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



extension ASN1Value {
    public var typedValue: TypedValue {
        guard let universalTag = universalTag else { return .bytes(bytes) }

        switch universalTag {
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
        case .integer:
            return .integer(bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) })
        case .printableString, .ia5String: // ia5String == ASCII
            return .string(String(bytes: UnsafeBufferPointer(start: bytes, count: bytes.count), encoding: String.Encoding.ascii) ?? "")
        case .utf8String, .t61String: // t61String = 8-bit ASCII
            return .string(String(bytes: UnsafeBufferPointer(start: bytes, count: bytes.count), encoding: String.Encoding.utf8) ?? "")
        default:
            return .bytes(bytes)
        }
    }
}


extension ASN1Value { // MARK: types
    public enum TypedValue {
        case integer(_: UInt64)
        case double(_: Double)
        case string(_: String)
        case objectIdentifer(_: [UInt64])
        case bytes(_: [UInt8])
    }
}


extension ASN1Value : CustomDebugStringConvertible {
    public var debugDescription: String {
        switch typedValue {
        case .integer(let integer):
            return "[\(bytes.count)]: \(integer)"
        case .double(let double):
            return "[\(bytes.count)]: \(double)"
        case .string(let string):
            return "[\(bytes.count)]: " + string
        case .objectIdentifer(let objectIdentifier):
            return objectIdentifier.map { "\($0)" }.joined(separator: ".")
        case .bytes(let bytes):
            if bytes.count < 16 {
                return "\(bytes)"
            } else {
                return "\(bytes.count) bytes"
            }
        }
    }
}
