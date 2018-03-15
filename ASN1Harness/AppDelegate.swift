//
//  AppDelegate.swift
//  ASN1Harness
//
//  Created by William Shipley on 3/9/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Certificate
import Cocoa
import Security


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let receiptURL = Bundle.main.url(forResource: "samplereceipt", withExtension: "cer") else { exit(-1) }
        let data = try! Data(contentsOf: receiptURL)
        let encodedBytes: [UInt8] = data.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: data.count)) }

        print("Start of encoded data dump:") // newline
        print("\(data as NSData)")
        print("total bytes: \(data.count)")

        let encodedItems = try! ASN1Reader.parse(encodedBytes)
        encodedItems.dump()



        let decoder = try! CMSDecoder.decoder(receiptURL)
        let bytes = try! decoder.decryptedContent()

        print("") // newline
        print("") // newline
        print("Start of decoded data dump:") // newline
        print("\(bytes)")
        print("total bytes: \(bytes.count)")

        let items = try! ASN1Reader.parse(bytes)
        items.dump()

        print("") // newline
        print("") // newline
        let receipt = try! Receipt(encodedBytes)
        print("\(receipt)")
        do {
            try receipt.validateReceipt()
        } catch {
            print("validation failed \(error)")
        }
//        dump(receipt)
    }
}

