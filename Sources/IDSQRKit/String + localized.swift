//
//  File.swift
//  
//
//  Created by Francesco Bianco on 09/02/22.
//

import Foundation

extension String {
    
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: .module, value: "", comment: "")
    }
    
}
