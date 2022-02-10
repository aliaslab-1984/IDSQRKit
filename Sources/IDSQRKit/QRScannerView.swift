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
    var tintColor: UIColor
    
    public init(scannedText: Binding<String>,
                tintColor: UIColor = .systemBlue) {
        self.scannedText = scannedText
        self.tintColor = tintColor
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
        controller.view.tintColor = tintColor
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: QRCapturerViewController, context: Context) {
        if tintColor != uiViewController.view.tintColor {
            uiViewController.view.tintColor = tintColor
        }
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
