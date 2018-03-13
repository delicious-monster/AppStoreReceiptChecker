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
        func nextByte() throws -> UInt8 {
            guard byteIndex < bytes.count else { throw Errors.prematureEndOfBytes }
            defer { byteIndex += 1 }
            return bytes[byteIndex]
        }

        while byteIndex < bytes.count {

            let identifier: ASN1Identifier = try {
                let firstByte = try nextByte()
                let firstByteTag = firstByte & ASN1Identifier.UniversalTag.highTagNumber.rawValue

                let tagSevenBitArray:[UInt8] = try {
                    if firstByteTag == ASN1Identifier.UniversalTag.mask { // 0bxxx1_1111 means tag is too long to be encoded in this byte
                        var sevenBitArray: [UInt8] = []
                        while true {
                            let nextTagByte = try nextByte()
                            let highBitMask: UInt8 = 0b1000_0000
                            let nextSevenBits = nextTagByte & ~highBitMask
                            sevenBitArray.append(nextSevenBits)
                            if (nextTagByte & highBitMask) == 0 { break }
                        }
                        return sevenBitArray
                    } else {
                        return [firstByteTag]
                    }
                }()
                let tagClass = ASN1Identifier.TagClass(rawValue: firstByte & ASN1Identifier.TagClass.mask)! // literally impossible for this ! to fail

                return ASN1Identifier(universalTag: (tagClass == .universal) ? ASN1Identifier.UniversalTag(rawValue: firstByteTag) : nil,
                                      tagSevenBitArray: tagSevenBitArray,
                                      method: ASN1Identifier.Method(rawValue: firstByte & ASN1Identifier.Method.mask)!, // ! also can't fail here
                                      tagClass: tagClass)
            }()

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
            let payloadBytes = Array(bytes[byteIndex..<byteIndex+payloadLength])
            byteIndex += payloadLength

            let item: ASN1Item = try {
                if identifier.method == .constructed {
                    return ASN1Item(identifier: identifier, children: try parse(payloadBytes))
                } else {
                    return ASN1Item(identifier: identifier, bytes: payloadBytes)
                }
            }()
            items += [item]
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
