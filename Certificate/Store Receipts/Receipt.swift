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
        case cannotGetMacAddress(kernReturn: kern_return_t)
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
        return """
        appReceiptEntries:
        \t\(appReceiptEntries.values.map { $0.debugDescription }.joined(separator: "\n\t"))

        unknownAppReceiptEntries:
        \t\(unknownAppReceiptEntries.values.map { $0.debugDescription }.joined(separator: "\n\t"))

        inAppPurchaseReceiptEntries:
        \t\(inAppPurchaseReceiptEntries.values.map { $0.debugDescription }.joined(separator: "\n\t"))

        unknownInAppPurchaseReceiptEntries:
        \t\(unknownInAppPurchaseReceiptEntries.values.map { $0.debugDescription }.joined(separator: "\n\t"))
        """
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
                else { throw Errors.receiptMalformedMissingEnclosingSet }

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
                    if ReceiptAttribute.AppReceiptFields(rawValue: Int(rawFieldType)) == .inAppPurchaseReceipt { // sub-dictionary for in-app purchase, we store this in a separate var
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
        let macAddressBytes = try macAddress()
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


    private func macAddress() throws -> [UInt8] {
        var masterPort = mach_port_t(MACH_PORT_NULL)
        try IOMasterPort(mach_port_t(MACH_PORT_NULL), &masterPort) | { throw Errors.cannotGetMacAddress(kernReturn: $0) }

        guard let matchingCFDictionary = IOBSDNameMatching(masterPort, 0, "en0") else { throw Errors.cannotGetMacAddress(kernReturn: 0) }

        var ioIterator = io_iterator_t(MACH_PORT_NULL)
        try IOServiceGetMatchingServices(masterPort, matchingCFDictionary, &ioIterator) | { throw Errors.cannotGetMacAddress(kernReturn: $0) }

        var macAddressCFData: CFData?
        var nextService = IOIteratorNext(ioIterator)
        while nextService != io_object_t(MACH_PORT_NULL) {
            var parentService = io_object_t(MACH_PORT_NULL)
            let result = IORegistryEntryGetParentEntry(nextService, kIOServicePlane, &parentService)
            if result == KERN_SUCCESS {
                macAddressCFData = (IORegistryEntryCreateCFProperty(parentService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as! CFData)
                IOObjectRelease(parentService)
            }
            IOObjectRelease(nextService)
            nextService = IOIteratorNext(ioIterator)
        }
        IOObjectRelease(ioIterator)

        let data = (macAddressCFData! as Data)
        return data.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: data.count)) }
    }

}
