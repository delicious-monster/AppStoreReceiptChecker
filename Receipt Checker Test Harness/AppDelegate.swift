//
//  AppDelegate.swift
//  Receipt Checker Test Harness
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
    @IBOutlet weak var textView: NSTextView!


    func applicationDidFinishLaunching(_ aNotification: Notification) {

        guard let receiptURL = Bundle.main.url(forResource: "samplereceipt", withExtension:"") else { exit(-1) }
        let receipt = try! Receipt(receiptURL)

        textView.string = receipt.debugDescription

        do {
            try receipt.validateReceipt()
        } catch {
            textView.string = textView.string + "\n\n" + "validation failed \(error) which is GOOD because this receipt isn't for this program, it's just a test."
        }
    }
}

