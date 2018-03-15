//
//  ReceiptAttribute.swift
//  Certificate
//
//  Created by William Shipley on 3/11/18.
//  Copyright © 2018 Delicious Monster Software, LLC. All rights reserved.
//

import Foundation

public struct ReceiptAttribute {
    public let fieldType: FieldType
    public let version: Int
    public let rawValue: ASN1Value
}


extension ReceiptAttribute { // MARK: calculated values
    public var decodedTypedValue: ASN1Value.TypedValue? {
        let cannotDecodeTypes: Set<FieldType> = [.app(.opaqueValue), .app(.sha1Hash)]
        if case .unknown(_) = fieldType { return nil }
        guard !cannotDecodeTypes.contains(fieldType) else { return .bytes(rawValue.bytes) } // NOTE: as of version 2 of the "opaqueValue" field it is NOT valid ASN.1, so we just return the raw bytes here!!!
        guard let decodedItem = (try? ASN1Reader.parse(rawValue.bytes))?.first else { return nil }
        guard case let .primitive(decodedValue) = decodedItem.payload else { return nil }
        return decodedValue.typedValue
    }
}

extension ReceiptAttribute : CustomDebugStringConvertible { // MARK: <CustomDebugStringConvertible>
    public var debugDescription: String {
        let fieldTypeString: String = {
            switch fieldType {
            case .app(let field):
                return ".app.\(field)"
            case .inApp(let field):
                return ".inApp.\(field)"
            case .unknown(let raw):
                return ".unknown.\(raw)"
            }
        }()
        return fieldTypeString + ((version != 1) ? " v\(version)" : "") + ": " + ((decodedTypedValue != nil) ? "\(decodedTypedValue!)" : "\(rawValue)")
    }
}

extension ReceiptAttribute { // MARK: types
    public enum FieldType : Hashable {
        case app(_: AppReceiptFields)
        case inApp(_: InAppPurchaseReceiptFields)
        case unknown(_: Int)

        // MARK: <Equatable>
        public static func == (lhs: FieldType, rhs: FieldType) -> Bool {
            switch (lhs, rhs) {
            case (.app(let leftField), .app(let rightField)):
                return leftField == rightField
            case (.inApp(let leftField), .inApp(let rightField)):
                return leftField == rightField
            case (.unknown(let leftField), .unknown(let rightField)):
                return leftField == rightField
            default:
                return false
            }
        }
        // MARK: <Hashable>
        public var hashValue: Int { // perfect hashing function assuming Apple doesn't add any tags over 0xffff
            switch self {
            case .app(let field):
                return field.rawValue
            case .inApp(let field):
                return 0x10000 + field.rawValue
            case .unknown(let field):
                return 0x20000 + field
            }
        }
    }

    public enum AppReceiptFields : Int {
        /**
         The app’s bundle identifier. `UTF8String`
         - Note: This corresponds to the value of CFBundleIdentifier in the Info.plist file. Use this value to validate if the receipt was indeed generated for your app.
         */
        case bundleIdentifier = 2
        /**
         The app’s version number. `UTF8String`
         - Note: This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in macOS) in the Info.plist.
         */
        case appVersion = 3
        /**
         An opaque value used, with other data, to compute the SHA-1 hash during validation. `A series of bytes`
         - Note: *UNOFFICIAL:* This is the DSPersonID (integer) for the App Store of the AppleID that bought the app.
         */
        case opaqueValue = 4
        /**
         A SHA-1 hash, used to validate the receipt. `20-byte SHA-1 digest`
         */
        case sha1Hash = 5
        /**
         The receipt for an in-app purchase. `SET of in-app purchase receipt attributes`
         - Note: In the ASN.1 file, there are multiple fields that all have type 17, each of which contains a single in-app purchase receipt.

         -  An empty array is a valid receipt.

         The in-app purchase receipt for a consumable product is added to the receipt when the purchase is made. It is kept in the receipt until your app finishes that transaction. After that point, it is removed from the receipt the next time the receipt is updated - for example, when the user makes another purchase or if your app explicitly refreshes the receipt.

         The in-app purchase receipt for a non-consumable product, auto-renewable subscription, non-renewing subscription, or free subscription remains in the receipt indefinitely.
         */
        case inAppPurchaseReceipt = 17
        /**
         The version of the app that was originally purchased. `UTF8STRING`
         - Note: This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in macOS) in the Info.plist file when the purchase was originally made.

         In the sandbox environment, the value of this field is always “1.0”.
         */
        case originalApplicationVersion = 19
        /**
         The date when the app receipt was created. `IA5STRING, interpreted as an RFC 3339 date`
         - Note: When validating a receipt, use this date to validate the receipt’s signature. "...make sure your app always uses the date from the Receipt Creation Date field to validate the receipt’s signature."
         */
        case receiptCreationDate = 12
        /**
         The date that the app receipt expires. `UTF8STRING`
         - Note: This key is present only for apps purchased through the Volume Purchase Program. If this key is not present, the receipt does not expire.
         When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
         */
        case receiptExpirationDate = 21
    }


    public enum InAppPurchaseReceiptFields : Int {
        /**
         The number of items purchased. `INTEGER`
         - Note: This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
         */
        case quantity = 1701
        /**
         The product identifier of the item that was purchased. `UTF8STRING`
         - Note: This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
         */
        case productIdentifier = 1702
        /**
         The transaction identifier of the item that was purchased. `UTF8STRING`
         - Note: This value corresponds to the transaction’s `transactionIdentifier` property.

         For a transaction that restores a previous transaction, this value is different from the transaction identifier of the original purchase transaction. In an auto-renewable subscription receipt, a new value for the transaction identifier is generated every time the subscription automatically renews or is restored on a new device.
         */
        case transactionIdentifier = 1703
        /**
         For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. `UTF8STRING`
         - Note: This value corresponds to the original transaction’s `transactionIdentifier` property.

         This value is the same for all receipts that have been generated for a specific subscription. This value is useful for relating together multiple iOS 6 style transaction receipts for the same individual customer’s subscription.
         */
        case originalTransactionIdentifier = 1705
        /**
         The date and time that the item was purchased. `IA5STRING, interpreted as an RFC 3339 date`
         - Note: This value corresponds to the transaction’s `transactionDate` property.

         For a transaction that restores a previous transaction, the purchase date is the same as the original purchase date. Use Original Purchase Date to get the date of the original transaction.

         In an auto-renewable subscription receipt, the purchase date is the date when the subscription was either purchased or renewed (with or without a lapse). For an automatic renewal that occurs on the expiration date of the current period, the purchase date is the start date of the next period, which is identical to the end date of the current period.
         */
        case purchaseDate = 1704
        /**
         For a transaction that restores a previous transaction, the date of the original transaction. `IA5STRING, interpreted as an RFC 3339 date`
         - Note: This value corresponds to the original transaction’s `transactionDate` property.

         In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
         */
        case originalPurchaseDate = 1706
        /**
         The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. `IA5STRING, interpreted as an RFC 3339 date`
         - Note: This key is only present for auto-renewable subscription receipts. Use this value to identify the date when the subscription will renew or expire, to determine if a customer should have access to content or service. After validating the latest receipt, if the subscription expiration date for the latest renewal transaction is a past date, it is safe to assume that the subscription has expired.
         */
        case subscriptionExpirationDate = 1708
        /**
         For an auto-renewable subscription, whether or not it is in the introductory price period. `INTEGER`
         - Note: This key is only present for auto-renewable subscription receipts. The value for this key is "true" if the customer’s subscription is currently in an introductory price period, or "false" if not.

         Note: If a previous subscription period in the receipt has the value “true” for either the is_trial_period or the is_in_intro_offer_period key, the user is not eligible for a free trial or introductory price within that subscription group.
         */
        case subscriptionIntroductoryPricePeriod = 1719
        /**
         For a transaction that was canceled by Apple customer support, the time and date of the cancellation. For an auto-renewable subscription plan that was upgraded, the time and date of the upgrade transaction. `IA5STRING, interpreted as an RFC 3339 date`
         - Note: Treat a canceled receipt the same as if no purchase had ever been made.

         Note: A canceled in-app purchase remains in the receipt indefinitely. Only applicable if the refund was for a non-consumable product, an auto-renewable subscription, a non-renewing subscription, or for a free subscription.
         */
        case cancellationDate = 1712
        /**
         The primary key for identifying subscription purchases. `INTEGER`
         - Note: This value is a unique ID that identifies purchase events across devices, including subscription renewal purchase events.
         */
        case webOrderLineItemID = 1711
    }
}
