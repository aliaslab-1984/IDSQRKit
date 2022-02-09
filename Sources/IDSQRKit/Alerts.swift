//
//  File.swift
//  
//
//  Created by Francesco Bianco on 09/02/22.
//

import Foundation
import UIKit

struct Alerts {
    
    static func permissionAlert(onSuccess: @escaping (() -> Void),
                                onDenied:  @escaping (() -> Void)) -> UIAlertController {
        let alert = UIAlertController(title: "alert_title".localized, message: "alert_message".localized, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "cancel_alert".localized, style: .cancel)
        let permissionAction = UIAlertAction(title: "give_access_action".localized, style: .default) { _ in
            QRCameraAccess.requestPermissionIfNeeded { granted in
                DispatchQueue.main.async {
                    if granted {
                        onSuccess()
                    } else {
                        onDenied()
                    }
                }
            }
        }
        alert.addAction(cancelAction)
        alert.addAction(permissionAction)
        return alert
    }
    
    static func settingsAlert() -> UIAlertController {
        
        let alert = UIAlertController(title: "setting_alert_title".localized, message: "setting_alert_message".localized, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "cancel_alert".localized, style: .cancel)
        let permissionAction = UIAlertAction(title: "setting_alert_go".localized, style: .default) { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
            }
        }
        alert.addAction(cancelAction)
        alert.addAction(permissionAction)
        return alert
    }
    
}
