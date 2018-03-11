//
//  ASN1Identifier.swift
//  ASN1
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation


public struct ASN1Identifier {
    // MARK: properties
    let universalTag: UniversalTag?
    let tagSevenBitArray: [UInt8]
    let method: Method
    let tagClass: TagClass
}


public extension ASN1Identifier { // MARK: methods

    public init(_ fetchByte: (() throws -> UInt8)) throws {
        let firstByte = try fetchByte()
        let firstByteTag = firstByte & UniversalTag.highTagNumber.rawValue

        let localTagClass = TagClass(rawValue: firstByte & TagClass.mask)! // literally impossible for this ! to fail
        if localTagClass == .universal {
            self.universalTag = UniversalTag(rawValue: firstByteTag)
        } else {
            self.universalTag = nil
        }

        if firstByteTag == UniversalTag.mask { // 0bxxx1_1111 means tag is too long to be encoded in this byte
            var sevenBitArray: [UInt8] = []
            while true {
                let nextByte = try fetchByte()
                let highBitMask: UInt8 = 0b1000_0000
                let nextSevenBits = nextByte & ~highBitMask
                sevenBitArray.append(nextSevenBits)
                if (nextByte & highBitMask) == 0 { break }
            }
            self.tagSevenBitArray = sevenBitArray
        } else {
            self.tagSevenBitArray = [firstByteTag]
        }

        self.method = Method(rawValue: firstByte & Method.mask)!
        self.tagClass = localTagClass
    }
}


extension ASN1Identifier : CustomDebugStringConvertible {
    public var debugDescription: String {
        let details = "{\(method), \(tagClass)}"
        if let tag = universalTag {
            return "<\(tag)>" + " " + details
        } else {
            return "\(tagSevenBitArray)" + " " + details
        }
    }
}


public extension ASN1Identifier { // MARK: types
    public enum Method : UInt8 {
        case primitive = 0b0000_0000
        case constructed = 0b0010_0000

        static let mask: UInt8 = 0b0010_0000
    }

    public enum TagClass : UInt8 {
        case universal = 0b0000_0000
        case application = 0b0100_0000
        case contextSpecific = 0b1000_0000
        case `private` = 0b1100_0000

        static let mask: UInt8 = 0b1100_0000
    }

    public enum UniversalTag : UInt8 {
        case eof = 0x0
        case boolean = 0x1
        case integer = 0x2
        case bitString = 0x3
        case octetString = 0x4
        case null = 0x5
        case objectID = 0x6
        case objectDescriptor = 0x7
        /* External type and instance-of type 0x08 */
        case real = 0x9
        case enumerated = 0xa
        case embeddedPDV = 0xb
        case utf8String = 0xc
        /* not used 0x0d */
        /* not used 0x0e */
        /* not used 0x0f */
        case sequence = 0x10
        case set = 0x11
        case numericString = 0x12
        case printableString = 0x13
        case t61String = 0x14
        case videotexString = 0x15
        case ia5String = 0x16
        case utcTime = 0x17
        case generalizedTime = 0x18
        case graphicString = 0x19
        case visibleString = 0x1a
        case generalString = 0x1b
        case universalString = 0x1c
        /* not used 0x1d */
        case bmpString = 0x1e

        case highTagNumber = 0x1f

        static let mask: UInt8 = 0x1f
    }
}
