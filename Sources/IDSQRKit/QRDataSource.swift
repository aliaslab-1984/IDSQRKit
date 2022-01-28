//
//  QRDataSource.swift
//  IDSignQRGenerator
//
//  Created by Francesco Bianco on 28/12/21.
//

import Foundation

public protocol QRDataSource: AnyObject {
    
    func didGet(qrData: String)
}
