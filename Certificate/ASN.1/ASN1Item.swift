//
//  ASN1Item.swift
//  ASN1
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation

public struct ASN1Item {
    public let identifier: ASN1Identifier
    public let payload: ASN1Item.PayloadType
}

extension ASN1Item { // MARK: init
    public init(identifier: ASN1Identifier, bytes: [UInt8]) {
        self.identifier = identifier
        self.payload = .primitive(ASN1Value(universalTag: identifier.universalTag, bytes: bytes))
    }

    public init(identifier: ASN1Identifier, children: [ASN1Item]) {
        self.identifier = identifier
        self.payload = .constructed(children)
    }
}


extension ASN1Item { // MARK: static methods
    public func dump(_ depth: Int = 0) {
        let indentString = [String](repeating: "  ", count: depth).reduce("", +)
        print(indentString, terminator: "")
        debugPrint(self)
        if case let .constructed(children) = payload {
            children.dump(depth + 1)
        }
    }
}
extension Sequence where Iterator.Element == ASN1Item {
    public func dump(_ depth: Int = 0) {
        forEach { $0.dump(depth) }
    }
}

extension ASN1Item { // MARK: static methods
    public enum PayloadType {
        case primitive(_: ASN1Value)
        case constructed(_: [ASN1Item])
    }
}

extension ASN1Item.PayloadType : CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .primitive(let value):
            return value.debugDescription
        case .constructed(let children):
            return "\(children.count) children"
        }
    }
}

extension ASN1Item : CustomDebugStringConvertible {
    public var debugDescription: String {
        let identifierString = identifier.debugDescription
        let payloadString = payload.debugDescription
        return identifierString + " " + payloadString
    }
}


