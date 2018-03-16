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
        // guard let receiptURL = Bundle.main.url(forResource: "AcornReceipts/Acorn Volume Purchase Receipt", withExtension: "cer") else { exit(-1) }
        // guard let receiptURL = Bundle.main.url(forResource: "AcornReceipts/Standard Acorn 6 receipt", withExtension: "cer") else { exit(-1) }

        guard let samplesFolderURL = Bundle.main.url(forResource: "MASReceipts", withExtension:"") else { exit(-1) }
        try! FileManager.default.contentsOfDirectory(at: samplesFolderURL, includingPropertiesForKeys: nil).forEach { subfolderURL in
            let receiptURL = subfolderURL.appendingPathComponent("receipt")

            print("")
            print(receiptURL)

            let receipt = try! Receipt(receiptURL)
            debugPrint(receipt)
            do {
                try receipt.validateReceipt()
            } catch {
                print("validation failed \(error)")
            }
        }
    }
}

