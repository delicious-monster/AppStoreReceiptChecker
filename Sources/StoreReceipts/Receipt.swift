//
//  Receipt.swift
//  Certificate
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import CommonCrypto
import Foundation


public struct Receipt {
    // MARK: properties
    let decoder: CMSDecoder
    let bytes: [UInt8]

    public let appReceiptEntries: [ReceiptAttribute.AppReceiptFields : ReceiptAttribute]
    public let unknownAppReceiptEntries: [Int : ReceiptAttribute]
    public let inAppPurchaseReceipts: [InAppPurchaseReceipt]

}

public struct InAppPurchaseReceipt {
    public let inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute]
    public let unknownInAppPurchaseReceiptEntries: [Int : ReceiptAttribute]
}

public extension Receipt { // MARK: init
    init() throws {
        try self.init(Bundle.main)
    }
    init(_ bundle: Bundle) throws {
        guard let receiptURL = bundle.appStoreReceiptURL else { throw Errors.missingStoreReceipt }
        try self.init(receiptURL)
    }
    init(_ url: URL) throws {
        try self.init(decoder: try CMSDecoder.decoder(url))
    }
    init(_ data: Data) throws {
        try self.init(decoder: try CMSDecoder.decoder(data))
    }
    init(_ bytes: [UInt8]) throws {
        try self.init(decoder: try CMSDecoder.decoder(bytes))
    }
}


extension Receipt { // MARK: public methods
    public func validateReceipt(expectedBundleIdentifier: String? = nil, expectedBundleMajorVersion: Int? = nil) throws {
        try checkBundleSignature()
        try checkBundleIdentifier(expectedBundleIdentifier)
        try checkMajorVersionNumber(expectedBundleMajorVersion)
        try checkReceiptSignature()
        try checkReceiptHash()
    }
}

extension Receipt { // MARK: errors
    public enum Errors : Error {
        // receipt reading
        case missingStoreReceipt
        case receiptMalformedMissingEnclosingSet
        case receiptInvalidEnclosingSetSequence
        // info.plist
        case bundleInfoDictionaryMissing
        // bundleIdentifier check
        case bundleInfoDictionaryBundleIdentifierDoesNotMatch
        case receiptMissingBundleIdentifier
        case receiptBundleIdentifierDoesNotMatch
        // major version # check
        case bundleInfoShortVersionStringMissing
        case bundleInfoShortVersionStringMalformed
        case bundleInfoDictionaryShortVersionDoesNotMatch
        case receiptMissingAppVersion
        case receiptShortVersionStringMalformed
        case appVersionTooNew
        // check hash
        case cannotGetMacAddress
        case receiptMalformedMissingOpaqueValue
        case receiptMalformedMissingSHA1Hash
        case receiptHashCheckFailed
        // check signers
        case cannotGetSignerCount(status: OSStatus)
        case noSignersFound
        case cannotGetSignerStatus(status: OSStatus)
        case noValidSigner
        // check bundle signature
        case cannotCreateStaticCode(status: OSStatus)
        case cannotCreateRequirement(status: OSStatus)
        case bundleSignatureCheckFailed(status: OSStatus)
    }
}


extension Receipt : CustomDebugStringConvertible { // MARK: <CustomDebugStringConvertible>
    public var debugDescription: String {
        """
        appReceiptEntries:
        \t\(appReceiptEntries.values.sorted { $0.fieldType.hashValue < $1.fieldType.hashValue }.map { $0.debugDescription }.joined(separator: "\n\t"))
        unknownAppReceiptEntries:
        \t\(unknownAppReceiptEntries.values.sorted { $0.fieldType.hashValue < $1.fieldType.hashValue }.map { $0.debugDescription }.joined(separator: "\n\t"))
        inAppPurchaseReceipts:
        \t\(inAppPurchaseReceipts.map { $0.debugDescription }.joined(separator: "\n\t"))
        """
    }
}

extension InAppPurchaseReceipt : CustomDebugStringConvertible { // MARK: <CustomDebugStringConvertible>
    public var debugDescription: String {
        """
        \tinAppPurchaseReceiptEntries:
        \t\t\(inAppPurchaseReceiptEntries.values.sorted { $0.fieldType.hashValue < $1.fieldType.hashValue }.map { $0.debugDescription }.joined(separator: "\n\t\t"))
        unknownInAppPurchaseReceiptEntries:
        \t\t\(unknownInAppPurchaseReceiptEntries.values.sorted { $0.fieldType.hashValue < $1.fieldType.hashValue }.map { $0.debugDescription }.joined(separator: "\n\t\t"))
        """
    }
}

extension ASN1Item {
    /// Extracts the fieldType, contents, and version value from a 3-valued ASN1Item sequence
    func extractProperty() throws -> (fieldType: UInt64, contents: ASN1Value, version: UInt64) {
        guard self.identifier.universalTag == .sequence,
            case let .constructed(rows) = self.payload,
            rows.count == 3 else { throw Receipt.Errors.receiptInvalidEnclosingSetSequence } // malformed contents
        // first row in sequence: field type
        guard rows[0].identifier.universalTag == .integer,
            case let .primitive(fieldTypeValue) = rows[0].payload,
            case let .integer(rawFieldType) = fieldTypeValue.typedValue else { throw Receipt.Errors.receiptInvalidEnclosingSetSequence }
        // second row in sequence: version #
        guard rows[1].identifier.universalTag == .integer,
            case let .primitive(versionValue) = rows[1].payload,
            case let .integer(version) = versionValue.typedValue else { throw Receipt.Errors.receiptInvalidEnclosingSetSequence }
        // third row in sequence: ASN.1 contents
        guard rows[2].identifier.universalTag == .octetString,
            case let .primitive(contentsValue) = rows[2].payload else { throw Receipt.Errors.receiptInvalidEnclosingSetSequence }

        return (rawFieldType, contentsValue, version)
    }
}


private extension Receipt { // MARK: private init
    private init(decoder: CMSDecoder) throws {

        let decryptedBytes = try decoder.decryptedContent()

        var appReceiptEntries: [ReceiptAttribute.AppReceiptFields : ReceiptAttribute] = [ : ]
        var unknownAppReceiptEntries: [Int : ReceiptAttribute] = [ : ]
        var inAppPurchaseReceipts: [InAppPurchaseReceipt] = []

        let items = try ASN1Reader.parse(decryptedBytes)

        guard let outermostSet = items.first,
            outermostSet.identifier.universalTag == .set,
            case let .constructed(receiptSequences) = outermostSet.payload
            else { throw Errors.receiptMalformedMissingEnclosingSet }

        try receiptSequences.forEach { sequence in
            let (rawFieldType, contentsValue, version) = try sequence.extractProperty()

            if ReceiptAttribute.AppReceiptFields(rawValue: Int(rawFieldType)) == .inAppPurchaseReceipt { // parse the in-app purchase array
                inAppPurchaseReceipts.append(try InAppPurchaseReceipt(bytes: contentsValue.bytes))
            } else if let appReceiptField = ReceiptAttribute.AppReceiptFields(rawValue: Int(rawFieldType)) {
                appReceiptEntries[appReceiptField] = ReceiptAttribute(fieldType: .app(appReceiptField), version: Int(version), rawValue: contentsValue)
            } else {
                unknownAppReceiptEntries[Int(rawFieldType)] = ReceiptAttribute(fieldType: .unknown(Int(rawFieldType)), version: Int(version), rawValue: contentsValue)
            }
        }

        self.decoder = decoder
        self.bytes = decryptedBytes
        self.appReceiptEntries = appReceiptEntries
        self.unknownAppReceiptEntries = unknownAppReceiptEntries

        self.inAppPurchaseReceipts = inAppPurchaseReceipts
    }
}

private extension InAppPurchaseReceipt {
    init(bytes: [UInt8]) throws {
        var inAppPurchaseReceiptEntries: [ReceiptAttribute.InAppPurchaseReceiptFields : ReceiptAttribute] = [ : ]
        var unknownInAppPurchaseReceiptEntries: [Int : ReceiptAttribute] = [ : ]

        let items = try ASN1Reader.parse(bytes)

        guard let outermostSet = items.first,
            outermostSet.identifier.universalTag == .set,
            case let .constructed(receiptSequences) = outermostSet.payload
            else { throw Receipt.Errors.receiptMalformedMissingEnclosingSet }

        try receiptSequences.forEach { sequence in
            let (rawFieldType, contentsValue, version) = try sequence.extractProperty()

            if let inAppPurchaseReceiptField = ReceiptAttribute.InAppPurchaseReceiptFields(rawValue: Int(rawFieldType)) {
                inAppPurchaseReceiptEntries[inAppPurchaseReceiptField] = ReceiptAttribute(fieldType: .inApp(inAppPurchaseReceiptField), version: Int(version), rawValue: contentsValue)
            } else {
                unknownInAppPurchaseReceiptEntries[Int(rawFieldType)] = ReceiptAttribute(fieldType: .unknown(Int(rawFieldType)), version: Int(version), rawValue: contentsValue)
            }
        }

        self.inAppPurchaseReceiptEntries = inAppPurchaseReceiptEntries
        self.unknownInAppPurchaseReceiptEntries = unknownInAppPurchaseReceiptEntries
    }
}


private extension Receipt { // MARK: private methods
    private func checkBundleIdentifier(_ expectedBundleIdentifier: String? = nil) throws {
        guard let bundleInfo = Bundle.main.infoDictionary else { throw Errors.bundleInfoDictionaryMissing }

        // the passed-in bundleIdentifier should match the one in our plist (in case pirates try to mess with plist) *and* the one in the receipt
       guard let bundleIdentifier = (bundleInfo["CFBundleIdentifier"] as? String) else { throw Errors.bundleInfoDictionaryMissing }
        if let expectedBundleIdentifier = expectedBundleIdentifier {
            guard expectedBundleIdentifier == bundleIdentifier else { throw Errors.bundleInfoDictionaryBundleIdentifierDoesNotMatch }
        }

        guard let receiptBundleIdentifierTypedValue = appReceiptEntries[.bundleIdentifier]?.decodedTypedValue,
            case let .string(receiptBundleIdentifier) = receiptBundleIdentifierTypedValue else { throw Errors.receiptMissingBundleIdentifier }
        guard receiptBundleIdentifier == bundleIdentifier else { throw Errors.receiptBundleIdentifierDoesNotMatch }
    }

    private func checkMajorVersionNumber(_ expectedBundleMajorVersion: Int? = nil) throws {
        guard let bundleInfo = Bundle.main.infoDictionary else { throw Errors.bundleInfoDictionaryMissing }

        func majorVersionFromFullVersionString(_ fullVersionString: String) -> Int? { // major version is digits up to first period
            if let rangeOfFirstPeriod = fullVersionString.range(of: ".") {
                return Int(fullVersionString[fullVersionString.startIndex..<rangeOfFirstPeriod.lowerBound])
            } else {
                return Int(fullVersionString)
            }
        }

        guard let bundleShortVersionString = bundleInfo["CFBundleShortVersionString"] as? String else { throw Errors.bundleInfoShortVersionStringMissing}
        guard let bundleMajorVersion = majorVersionFromFullVersionString(bundleShortVersionString) else { throw Errors.bundleInfoShortVersionStringMalformed }

        if let expectedBundleMajorVersion = expectedBundleMajorVersion {
            guard bundleMajorVersion == expectedBundleMajorVersion else { throw Errors.bundleInfoDictionaryShortVersionDoesNotMatch }
        }

        guard let receiptAppVersionTypedValue = appReceiptEntries[.appVersion]?.decodedTypedValue,
            case let .string(receiptAppVersionString) = receiptAppVersionTypedValue else { throw Errors.receiptMissingAppVersion }
        guard let receiptMajorVersion = majorVersionFromFullVersionString(receiptAppVersionString) else { throw Errors.receiptShortVersionStringMalformed }
        guard receiptMajorVersion <= bundleMajorVersion else { throw Errors.appVersionTooNew }

    }

    private func checkReceiptHash() throws {
        guard let macAddressBytes = ProcessInfo.processInfo.macAddress else { throw Errors.cannotGetMacAddress }
        guard let opaqueValueRawBytes = appReceiptEntries[.opaqueValue]?.rawValue.bytes else { throw Errors.receiptMalformedMissingOpaqueValue }
        guard let bundleIdentifierRawBytes = appReceiptEntries[.bundleIdentifier]?.rawValue.bytes else { throw Errors.receiptMissingBundleIdentifier }

        let digestBytes = macAddressBytes + opaqueValueRawBytes + bundleIdentifierRawBytes

        var digestBuffer: [UInt8] = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(digestBytes, CC_LONG(digestBytes.count), &digestBuffer)

        guard let receiptDigestRawBytes = appReceiptEntries[.sha1Hash]?.rawValue.bytes else { throw Errors.receiptMalformedMissingSHA1Hash }
        guard digestBuffer == receiptDigestRawBytes else { throw Errors.receiptHashCheckFailed }
    }

    private func checkReceiptSignature() throws {
        var  numSigners = 0
        try CMSDecoderGetNumSigners(decoder, &numSigners) | { throw Errors.cannotGetSignerCount(status: $0) }
        guard numSigners > 0 else { throw Errors.noSignersFound }

        let policyRef = SecPolicyCreateBasicX509()
        var signerStatus: CMSSignerStatus = .unsigned
        var trustRef: SecTrust?
        var certVerifyResult: OSStatus = 0
        try CMSDecoderCopySignerStatus(decoder, 0, policyRef, true, &signerStatus, &trustRef, &certVerifyResult) | { throw Errors.cannotGetSignerStatus(status: $0) }
        guard signerStatus == .valid else { throw Errors.noValidSigner }
    }

    private func checkBundleSignature() throws {
        var staticCode: SecStaticCode?
        try SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode) | { throw Errors.cannotCreateStaticCode(status: $0) }

        var requirement: SecRequirement?
        let requirementText = "anchor apple generic" // for code signed by Apple
        try SecRequirementCreateWithString(requirementText as CFString, [], &requirement) | { throw Errors.cannotCreateRequirement(status: $0) }

        try SecStaticCodeCheckValidity(staticCode!, [], requirement!) | { throw Errors.bundleSignatureCheckFailed(status: $0) }
    }
}
