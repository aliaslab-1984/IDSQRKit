//
//  File.swift
//  
//
//  Created by Francesco Bianco on 28/01/22.
//

import Foundation

public enum QRLogSeverity: Int, Comparable, CaseIterable, Codable {
    
    case verbose = 10
    case debug = 20
    case info = 30
    case warning = 40
    case error = 50
    
    public static func < (lhs: QRLogSeverity, rhs: QRLogSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public protocol QREventLogger: AnyObject {
    
    func qrEventOccurred(event: String, level: QRLogSeverity)
    
}
