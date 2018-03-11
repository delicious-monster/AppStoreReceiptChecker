//
//  AppDelegate.swift
//  ASN1Harness
//
//  Created by William Shipley on 3/9/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import ASN1
import Cocoa
import Security


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let receiptURL = Bundle.main.url(forResource: "samplereceipt", withExtension: "cer") else { exit(-1) }
        let data = try! Data(contentsOf: receiptURL)

        let decoder: CMSDecoder = {
            var decoderOptional: CMSDecoder?
            print("\(CMSDecoderCreate(&decoderOptional))")
            return decoderOptional!
        }()

        // Decrypt the message
        data.withUnsafeBytes { bytes in
            print("\(CMSDecoderUpdateMessage(decoder, bytes, data.count))")
        }
        print("\(CMSDecoderFinalizeMessage(decoder))")

        // Get the decrypted content
        let decryptedData: Data =  {
            var dataOptional: CFData?
            print("\(CMSDecoderCopyContent(decoder, &dataOptional))")
            return (dataOptional as Data?)!
        }()


        print("Start of encoded data dump:") // newline
        print("\(data as NSData)")
        print("total bytes: \(data.count)")


        let encodedBytes: [UInt8] = data.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: data.count)) }
        let encodedItems = try! ASN1Reader.parse(encodedBytes)
        encodedItems.dump()

        print("") // newline
        print("") // newline
        print("Start of decoded data dump:") // newline
        print("\(decryptedData as NSData)")
        print("total bytes: \(decryptedData.count)")

        let bytes: [UInt8] = decryptedData.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: decryptedData.count)) }
        let items = try! ASN1Reader.parse(bytes)
        items.dump()
    }
}

