//
//  Receipt.swift
//  Certificate
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation

public struct Receipt {
    // MARK: properties
    let decoder: CMSDecoder
    let bytes: [UInt8]

    let appReceiptEntries: [ReceiptAttribute.AppReceiptFields : ReceiptAttribute]
    let inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute]
    let unknownReceiptEntries: [Int : ReceiptAttribute]
}


public extension Receipt { // MARK: init
    public init() throws {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { throw Errors.missingStoreReceipt }
        try self.init(receiptURL)
    }

    public init(_ url: URL) throws {
        try self.init(decoder: try CMSDecoder.decoder(url))
    }
    public init(_ data: Data) throws {
        try self.init(decoder: try CMSDecoder.decoder(data))
    }
    public init(_ bytes: [UInt8]) throws {
        try self.init(decoder: try CMSDecoder.decoder(bytes))
    }
}


extension Receipt { // MARK: errors
    public enum Errors : Error {
        case missingStoreReceipt
        case storeReceiptMalformedMissingEnclosingSet
    }
}


private extension Receipt { // MARK: private init
    private init(decoder: CMSDecoder) throws {

        let bytes =  try decoder.decryptedContent()
        let items = try ASN1Reader.parse(bytes)

        guard let outermostSet = items.first,
            outermostSet.identifier.universalTag == .set,
            case let .constructed(sequences) = outermostSet.payload
            else { throw Errors.storeReceiptMalformedMissingEnclosingSet }

        var appReceiptEntries: [ReceiptAttribute.AppReceiptFields : ReceiptAttribute] = [ : ]
        var inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute] = [ : ]
        var unknownReceiptEntries: [Int : ReceiptAttribute] = [ : ]

        sequences.forEach { sequence in
            guard sequence.identifier.universalTag == .sequence,
                case let .constructed(rows) = sequence.payload,
                rows.count == 3 else { return } // malformed contents

            // first row in sequence: field type
            guard rows[0].identifier.universalTag == .integer,
                case let .primitive(fieldTypeValue) = rows[0].payload,
                case let .integer(rawFieldType) = fieldTypeValue.typedValue else { return }
            let fieldType: ReceiptAttribute.FieldType = {
                if let appReceiptField = ReceiptAttribute.AppReceiptFields(rawValue: Int(rawFieldType)) {
                    return ReceiptAttribute.FieldType.app(appReceiptField)
                } else {
                    return ReceiptAttribute.FieldType.unknown(Int(rawFieldType))
                }
            }()

            // second row in sequence: version #
            guard rows[1].identifier.universalTag == .integer,
                case let .primitive(versionValue) = rows[1].payload,
                case let .integer(version) = versionValue.typedValue else { return }

            // second row in sequence: ASN.1 contents
            guard rows[2].identifier.universalTag == .octetString,
                case let .primitive(contentsValue) = rows[2].payload else { return }

            let receiptAttribute = ReceiptAttribute(fieldType: fieldType, version: Int(version), value: contentsValue)
            print("attribute: {\(fieldType), \(version), \(contentsValue)}")
            if case let .app(field) = fieldType {
                appReceiptEntries[field] = receiptAttribute
            } else {
                unknownReceiptEntries[Int(rawFieldType)] = receiptAttribute
            }
        }

        self.decoder = decoder
        self.bytes = bytes
        self.appReceiptEntries = appReceiptEntries
        self.inAppPurchaseReceiptEntries = inAppPurchaseReceiptEntries
        self.unknownReceiptEntries = unknownReceiptEntries
    }
}
