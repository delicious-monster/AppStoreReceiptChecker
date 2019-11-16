//
//  MACAddress.swift
//  App Store Receipt Checker
//
//  Created by William Shipley on 11/16/19.
//  Copyright © 2019 Delicious Monster Software, LLC. All rights reserved.
//

import CommonCrypto
import Foundation
import IOKit.network


public extension ProcessInfo {

    func macAddress() -> [UInt8]? {
        // create matching services dictionary for IOKit to enumerate — this is some UGLY swift, since we're switching from and then back to `CFDictionary`s
        guard var matchingDictionary = IOServiceMatching(kIOEthernetInterfaceClass) as? [String : CFTypeRef] else { return nil }
        matchingDictionary[kIOPropertyMatchKey] = [kIOPrimaryInterface: true] as CFDictionary // there can be only one

        // create ethernet iterator
        var ioIterator = io_iterator_t(MACH_PORT_NULL)
        guard IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary as CFDictionary, &ioIterator) != 0 else { return nil }
        if ioIterator == MACH_PORT_NULL { return nil } // "If NULL is returned, the iteration was successful but found no matching services."
        defer { IOObjectRelease(ioIterator) }

        // only one service can be primary AND our ethernet interface
        let firstAndOnlyService = IOIteratorNext(ioIterator)
        guard firstAndOnlyService != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(firstAndOnlyService) }

        // get that service's parent because the MAC address is there, for reasons
        var parentService = io_object_t(MACH_PORT_NULL)
        guard IORegistryEntryGetParentEntry(firstAndOnlyService, kIOServicePlane, &parentService) != 0 else { return nil }
        defer { IOObjectRelease(parentService) }

        // finally, get the darn MAC
        guard let possibleMACAddressUnmanagedCFData = IORegistryEntryCreateCFProperty(parentService, kIOMACAddress as CFString, kCFAllocatorDefault, 0),
            let macAddressData = possibleMACAddressUnmanagedCFData.takeRetainedValue() as? Data else { return nil }

        return macAddressData.withUnsafeBytes { Array($0) }
    }
}
