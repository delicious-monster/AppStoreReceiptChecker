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
    public let bytes: [UInt8]?
    public let children: [ASN1Item]?
}


extension ASN1Item { // MARK: static methods
    public func dump(_ depth: Int = 0) {
        let indentString = [String](repeating: "  ", count: depth).reduce("", +)
        print(indentString, terminator: "")
        debugPrint(self)
        children?.dump(depth + 1)
    }
}


extension Sequence where Iterator.Element == ASN1Item {
    public func dump(_ depth: Int = 0) {
        forEach { $0.dump(depth) }
    }
}


extension ASN1Item : CustomDebugStringConvertible {
    public var debugDescription: String {
        let identifierString = identifier.debugDescription
        let bytesString: String = {
            if let bytes = bytes { return "\(bytes.count) bytes" } else { return "" }
        }()
        let childrenString: String = {
            if let children = children { return "\(children.count) children" } else { return "" }
        }()
        return identifierString + " " + bytesString + ((bytesString.isEmpty || childrenString.isEmpty) ? "" : " ") + childrenString
    }
}
