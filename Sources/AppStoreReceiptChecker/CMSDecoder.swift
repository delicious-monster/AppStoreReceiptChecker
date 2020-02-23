//
//  CMSDecoder.swift
//  Certificate
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation
import Security


public extension CMSDecoder { // MARK: static functions
    static func decoder() throws -> CMSDecoder {
        var decoderOptional: CMSDecoder?
        try CMSDecoderCreate(&decoderOptional) | { throw Errors.cannotCreateDecoder(status: $0) }
        return decoderOptional!
    }

    static func decoder(_ bytes: [UInt8]) throws -> CMSDecoder {
        let newDecoder = try decoder()
        try CMSDecoderUpdateMessage(newDecoder, bytes, bytes.count) | { throw Errors.cannotUpdateMessage(status: $0) }
        try CMSDecoderFinalizeMessage(newDecoder) | { throw Errors.cannotFinalizeMessage(status: $0) }
        return newDecoder
    }
    static func decoder(_ data: Data) throws -> CMSDecoder {
        return try data.withUnsafeBytes { try decoder(Array($0)) }
    }

    static func decoder(_ url: URL) throws -> CMSDecoder {
        return try decoder(try Data(contentsOf: url))
    }
}


public extension CMSDecoder { // MARK: functions
    /// decrypted message
    func decryptedContent() throws -> [UInt8] {
        var dataOptional: CFData?
        try CMSDecoderCopyContent(self, &dataOptional) | { throw Errors.cannotGetDecryptedData(status: $0) }
        let data = dataOptional! as Data
        return data.withUnsafeBytes { Array($0) }
    }
}

public extension CMSDecoder { // MARK: errors
    enum Errors : Error {
        case cannotCreateDecoder(status: OSStatus)
        case missingStoreReceipt
        case cannotUpdateMessage(status: OSStatus) // Failed to decode receipt data: Update message
        case cannotFinalizeMessage(status: OSStatus) // Failed to decode receipt data: Finalize message
        case cannotGetDecryptedData(status: OSStatus) // Failed to decode receipt data: Get decrypted content
        case cannotGetSignerCount(status: OSStatus) // Failed to check receipt signature: Get signer count
        case noSigners // Failed to check receipt signature: No signer found
        case cannotGetSignerStatus(status: OSStatus) // Failed to check receipt signature: Get signer status
        case noValidSigner(status: CMSSignerStatus) // Failed to check receipt signature: No valid signer
    }
}

