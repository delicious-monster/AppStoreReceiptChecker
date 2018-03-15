#  Certificate Framework README

This framework was written by Wil Shipley at Delicious Monster Software.

The receipt validation parts of this were based on the popular 'RVNReceiptValidation' code by Satoshi Numata. The big difference here is I've written it all in Swift, for better or worse.

If all you want to do is check to make sure your app is licensed from the App Store, you would write code like this:

```
func applicationWillFinishLaunching(_ notification: Notification) {
    do {
        let receipt = Receipt() // automatically loads App Store receipt if no parameters are given
        try receipt.validateReceipt(expectedBundleIdentifier: "com.mycompany.MyApp", expectedBundleMajorVersion: 1) // the optional parameters here help prevent tampering with Info.plist or certificate
    } catch {
        print("validation failed \(error)")
        _exit(173)
    }

    // ...your code...
}
```

