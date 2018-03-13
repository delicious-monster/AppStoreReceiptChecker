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
}


public extension Receipt { // MARK: init
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


extension Receipt { // MARK: static functions
    static public func receiptForAppStore() throws -> Receipt {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { throw Errors.missingStoreReceipt }
        return try self.init(receiptURL)
    }

}


extension Receipt { // MARK: errors
    public enum Errors : Error {
        case missingStoreReceipt
    }
}


private extension Receipt { // MARK: private init
    private init(decoder: CMSDecoder) throws {
        self.decoder = decoder
        self.bytes = try decoder.decryptedContent()
    }
}
