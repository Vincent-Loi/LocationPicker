//
//  Strings+Extension.swift
//  LocationPicker
//
//  Created by Terenze Yuen on 06/03/2017.
//  Copyright © 2017 almassapargali. All rights reserved.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
}
