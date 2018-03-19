#  App Store Certificate Checker Framework README

## by *Wil Shipley* at *Delicious Monster Software*

The framework was written to be a Swift-y way to validate App Store receipts.

This contains receipt verification code plus a semi-complete ASN.1 parser (but not emitter) because the ASN.1 reading functions that Apple ships actually cannot be used from Swift, due to badly annotated headers combined with an incredibly horrrifying API (which they may have inherited from the standards body, to be fair).

The receipt validating parts of this were based on my studies of the popular [_RVNReceiptValidation_](https://gist.github.com/sazameki/3026845) code by _Satoshi Numata_, which in turn was based on Apple's [documentation on verifying receipts](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html#//apple_ref/doc/uid/TP40010573-CH105-SW1). Our entire community owes a huge debt to Satoshi, as it seems to me the most popular receipt validation code I've seen in the last 10 years.

This work is licensed under the Creative Commons Attribution 4.0 International License. To view a copy of this license, visit the [Creative Commons](http://creativecommons.org/licenses/by/4.0/) site.

***

If all you want to do is check to make sure your app is licensed from the App Store, you would write code like this:

```func applicationWillFinishLaunching(_ notification: Notification) {
    do {
        let receipt = Receipt() // automatically loads App Store receipt if no parameters are given
        try receipt.validateReceipt(expectedBundleIdentifier: "com.mycompany.MyApp", expectedBundleMajorVersion: 1) // the optional parameters here help prevent tampering with Info.plist or certificate
    } catch {
        #if DEBUG
            print("validation failed \(error)") // NOTE: in production you might not want to print the error as that would help pirates figure out how to attack your code
        #endif
        _exit(173) // when launched from Finder (not Xcode!) this code will force the App Store daemon to download a new test receipt and stick it inside the app's wrapper
    }

    // ...your code...
}
```

You can also use the ASN.1 parser to take apart receipts and certificates and poke around in them. Note that often ASN.1 is used as a wrapper for values that are more ASN.1 — App Store receipts at least three levels of wrapping this way, four if they have in-app purchases.

***

Notes:

* The App Store receipt is just a certificate in ASN.1 — you can inspect it using QuickLook or Keychain Access by adding ".cer" to the "receipt". You can also inspect it using the ASN1Reader class in this framework.
* Inside the App Store receipt certificate is a signed payload in ASN.1 format (again) which consists of a set of sequences, each of which resolves to a single field. The sequences have three values: an integer tag which labels the field ([see discussion on tags here](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html)), an integer version number for the field, and an octet-string (which is ASN.1-speak for "byte array") which contains the value of the field.
* Most of the field values in a decoded App Store receipt are actually more ASN.1 packed inside the octet-string, but some aren't (notably the 'opaque hash' and 'sha1 hash'), so you can crash if you try to parse all the values as ASN.1 willy-nillly. If you want to go exploring, though, a lot of the undocumented fields' contents _are_ in ASN.1, so you can run the decoder on them and see what's what.

***

Things to fix:

* This requires modifications to work with iOS. This would be a wonderful addition.

* The ASN.1 parser will leave some obscure value types as raw bytes, because I wasn't able to test them as they aren't in common use any more. It'd be wonderful if someone made this more complete.

* It'd be kinda fun to have a complete ASN.1 writer, as well, for writing [Distinguish Encoding Rules](https://en.wikipedia.org/wiki/X.690) (used by security objets a lot).

* The ASN.1 parser can _crash_ in Swift if it's fed garbage data, in particular if the 'long-form length' byte count is > 8, or is equal to 8 and overflows into the sign bit of an Int64 (eg, Int nowadays). *This would be a great area for someone to fix.* (Note that it'd be nuts for the number of bytes in the length to be 2^63 (9,223,372,036,854,775,807) or more — that'd give a maximum possible field length of 2^(8 * 9,223,372,036,854,775,807) which would imply a file that is as large than the known universe, so there's no reason to support this.)
