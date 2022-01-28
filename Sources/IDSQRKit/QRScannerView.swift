//
//  QRScannerView.swift
//  IDSignQRGenerator
//
//  Created by Francesco Bianco on 28/12/21.
//

import Foundation

#if !arch(arm)

import SwiftUI
import UIKit

@available(iOS 13.0, *)
public struct QRScannerView {
    
    var scannedText: Binding<String>
    
    public init(scannedText: Binding<String>) {
        self.scannedText = scannedText
    }
}

@available(iOS 13.0, *)
extension QRScannerView: UIViewControllerRepresentable {
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(scannedText)
    }
    
    public func makeUIViewController(context: Context) -> QRCapturerViewController {
        let controller = QRCapturerViewController(shouldDismiss: true)
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: QRCapturerViewController, context: Context) {
        
    }
    
    public typealias UIViewControllerType = QRCapturerViewController
    
    
    public class Coordinator: NSObject, QRDataSource {
        
        var scannedText: Binding<String>
        
        init(_ text: Binding<String>) {
            self.scannedText = text
        }
        
        public func didGet(qrData: String) {
            scannedText.wrappedValue = qrData
        }
    }
}

#endif
