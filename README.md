#  Certificate Framework README

This framework was written by Wil Shipley at Delicious Monster Software.

Certificate was written to be a Swift way to validate App Store receipts. In the process I wrote a semi-complete ASN.1 parser (but not writer) because the ASN.1 reading functions that Apple ships actually cannot be used from Swift due to badly annotated headers and an incredibly horrrifying design (which I think they inherited from the standard body, to be fair).

The receipt validation parts of this were based on my studies of the popular _RVNReceiptValidation_ code by _Satoshi Numata_. Our entire community owes a huge debt to Satoshi, as his is pretty much the only publicly available receipt validation code I've seen in the last 10 years.

If all you want to do is check to make sure your app is licensed from the App Store, you would write code like this:

```
func applicationWillFinishLaunching(_ notification: Notification) {
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

Notes:

- Most fields in an unwrapped receipt are ASN.1 tucked into octets, but some aren't (notably the 'opaque hash' and 'sha1 hash'), so you can crash if you try to parse all the values as ASN.1 willy-nillly. If you want to go exploring, though, a lot of the undocumented fields' contents _are_ in ASN.1, so you can run the decoder on them and see what's what.


Bugs:

- The ASN.1 parser can crash in Swift if it's fed garbage data, in particular if the 'long-form length' byte count is > 8, or is equal to 8 and overflows into the sign bit of an Int64 (eg, Int nowadays). *This would be a great area for someone to fix.* (Note that it'd be nuts for the number of bytes in the length to be 2^63 (9,223,372,036,854,775,807) or more — that'd give a maximum possible field length of 2^(8 * 9,223,372,036,854,775,807) which would imply a file that is as large than the known universe, so there's no reason to support this.)


