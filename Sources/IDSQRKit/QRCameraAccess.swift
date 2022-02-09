//
//  File.swift
//  
//
//  Created by Francesco Bianco on 09/02/22.
//

import Foundation
import AVKit

public struct QRCameraAccess {
    
    private static let cameraType: AVMediaType = .video
    
    public static func hasPermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: cameraType)
    }
    
    public static func requestPermissionIfNeeded(_ grantedClosure: @escaping (Bool) -> Void) {
        switch hasPermission() {
        case .authorized:
            grantedClosure(true)
        case .denied:
            grantedClosure(false)
        case .restricted:
            grantedClosure(false)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: cameraType) { granted in
                grantedClosure(granted)
            }
        @unknown default:
            grantedClosure(false)
        }
    }
    
}
