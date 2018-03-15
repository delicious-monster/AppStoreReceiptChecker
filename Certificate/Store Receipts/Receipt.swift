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
    let unknownAppReceiptEntries: [Int : ReceiptAttribute]
    let inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute]
    let unknownInAppPurchaseReceiptEntries: [Int : ReceiptAttribute]
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

        let decryptedBytes = try decoder.decryptedContent()

        var appReceiptEntries: [ReceiptAttribute.AppReceiptFields : ReceiptAttribute] = [ : ]
        var unknownAppReceiptEntries: [Int : ReceiptAttribute] = [ : ]
        var inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute] = [ : ]
        var unknownInAppPurchaseReceiptEntries: [Int : ReceiptAttribute] = [ : ]

        func parseBytes(_ bytes: [UInt8], intoInAppPurchaseReceipt: Bool = false) throws {
            let items = try ASN1Reader.parse(bytes)

            guard let outermostSet = items.first,
                outermostSet.identifier.universalTag == .set,
                case let .constructed(receiptSequences) = outermostSet.payload
                else { throw Errors.storeReceiptMalformedMissingEnclosingSet }

            try receiptSequences.forEach { sequence in
                guard sequence.identifier.universalTag == .sequence,
                    case let .constructed(rows) = sequence.payload,
                    rows.count == 3 else { return } // malformed contents

                // first row in sequence: field type
                guard rows[0].identifier.universalTag == .integer,
                    case let .primitive(fieldTypeValue) = rows[0].payload,
                    case let .integer(rawFieldType) = fieldTypeValue.typedValue else { return }
                // second row in sequence: version #
                guard rows[1].identifier.universalTag == .integer,
                    case let .primitive(versionValue) = rows[1].payload,
                    case let .integer(version) = versionValue.typedValue else { return }
                // third row in sequence: ASN.1 contents
                guard rows[2].identifier.universalTag == .octetString,
                    case let .primitive(contentsValue) = rows[2].payload else { return }

                if !intoInAppPurchaseReceipt {
                    if rawFieldType == ReceiptAttribute.AppReceiptFields.inAppPurchaseReceipt.rawValue { // sub-dictionary for in-app purchase, we store this in a separate var
                        try parseBytes(contentsValue.bytes, intoInAppPurchaseReceipt: true)

                    } else if let appReceiptField = ReceiptAttribute.AppReceiptFields(rawValue: Int(rawFieldType)) {
                        appReceiptEntries[appReceiptField] = ReceiptAttribute(fieldType: .app(appReceiptField), version: Int(version), rawValue: contentsValue)
                    } else {
                        unknownAppReceiptEntries[Int(rawFieldType)] = ReceiptAttribute(fieldType: .unknown(Int(rawFieldType)), version: Int(version), rawValue: contentsValue)
                    }
                } else {
                    if let inAppPurchaseReceiptField = ReceiptAttribute.InAppPurchaseReceiptFields(rawValue: Int(rawFieldType)) {
                        inAppPurchaseReceiptEntries[inAppPurchaseReceiptField] = ReceiptAttribute(fieldType: .inApp(inAppPurchaseReceiptField), version: Int(version), rawValue: contentsValue)
                    } else {
                        unknownInAppPurchaseReceiptEntries[Int(rawFieldType)] = ReceiptAttribute(fieldType: .unknown(Int(rawFieldType)), version: Int(version), rawValue: contentsValue)
                    }
                }
            }
        }

        try parseBytes(decryptedBytes)

        self.decoder = decoder
        self.bytes = decryptedBytes
        self.appReceiptEntries = appReceiptEntries
        self.unknownAppReceiptEntries = unknownAppReceiptEntries
        self.inAppPurchaseReceiptEntries = inAppPurchaseReceiptEntries
        self.unknownInAppPurchaseReceiptEntries = unknownInAppPurchaseReceiptEntries
    }
}
