# IDSQRKit

This package aim to help you to set up a QRScanner in no time!
It works perfectly on UIKit and SwiftUI!

### To start using the SDK on UIKit:

```
import IDSQRKit

// The shouldDismiss, tells to the viewController if, whenever it finds a match it should dismiss or not.
let scanController = QRCapturerViewController(shouldDismiss: true)

```

In order to receive the scanned text, you should provide an object that conforms to `QRDataSource` like so:

```

scanController.delegate = self

// ...

func didGet(qrData: String) {
    print("I got this string from the QR Code: \(qrData)")
}

```

That's it! Happy Scanning!

### To start using the SDK on SwiftUI:

```
struct YourView: View {
    
    @Binding private var scannedText: String = ""
    
    var body: some View {
        QRScanView(scannedText: $scannedText)
    }
    
}
```

That's it, easy right ?!
That's it! Happy Scanning!

