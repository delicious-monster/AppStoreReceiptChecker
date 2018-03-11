//
//  ASN1Reader.swift
//  ASN1
//
//  Created by William Shipley on 3/9/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation


public class ASN1Reader {
}


public extension ASN1Reader { // MARK: public methods
    public static func parse(_ bytes: [UInt8]) throws -> [ASN1Item] {
        var items: [ASN1Item] = []

        var byteIndex = 0
        while byteIndex < bytes.count {

            func nextByte() throws -> UInt8 {
                guard byteIndex < bytes.count else { throw Errors.prematureEndOfBytes }
                defer { byteIndex += 1 }
                return bytes[byteIndex]
            }

            let identifier = try ASN1Identifier({ try nextByte() })

            let payloadLength: Int = try {
                let firstLengthByte = try nextByte()
                let highBitMask: UInt8 = 0b1000_0000
                let firstBytePayload = firstLengthByte & ~highBitMask
                if (firstLengthByte & highBitMask) == 0 {  // short form, length is in lower 7 bits
                    return Int(firstBytePayload)
                } else { // long-form, lower bits are count of length bytes that follow
                    let lengthBytesCount = firstBytePayload
                    guard lengthBytesCount <= MemoryLayout<Int>.size else { throw Errors.lengthTooLarge }
                    let lengthBytesArray: [UInt8] = try (1...lengthBytesCount).map { _ in try nextByte() }
                    return lengthBytesArray.reduce(0) { ($0 << 8) | Int($1) }
                }
                }()
            let payloadBytes = Array(bytes[byteIndex..<(byteIndex+payloadLength)])

            let item: ASN1Item
            if identifier.method == .constructed {
                item = ASN1Item(identifier: identifier, bytes: nil, children: try parse(payloadBytes))
            } else {
                item = ASN1Item(identifier: identifier, bytes: payloadBytes, children: nil)
            }
            items += [item]
            byteIndex += payloadLength
        }
        return items
    }
}


public extension ASN1Reader { // MARK: Errors
    public enum Errors : Error {
        case prematureEndOfBytes
        case lengthTooLarge
    }
}
