//
//  OSStatus.swift
//  Certificate
//
//  Created by William Shipley on 3/15/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation

extension OSStatus { // MARK: operators
    internal static func | (status: OSStatus, throwingBlock: (OSStatus) throws -> Void) throws {
        if status != 0 { try throwingBlock(status) }
    }
}
