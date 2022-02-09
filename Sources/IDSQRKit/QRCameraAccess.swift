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
    
    public static func hasPermission() -> Bool {
        let authStatus = AVCaptureDevice.authorizationStatus(for: cameraType)
        return authStatus == .authorized
    }
    
    public static func requestPermissionIfNeeded(_ grantedClosure: @escaping (Bool) -> Void) {
        guard !hasPermission() else {
            grantedClosure(true)
            return
        }
        
        AVCaptureDevice.requestAccess(for: cameraType) { granted in
            grantedClosure(granted)
        }
    }
    
}
