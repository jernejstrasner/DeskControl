//
//  Formatting.swift
//  desk
//
//  Created by Jernej Strasner on 28. 10. 23.
//  Copyright © 2023 Forti. All rights reserved.
//

import Foundation

public func formatPosition(_ position: Int?) -> String {
    guard let position = position else {
        return "-.-"
    }
    return String(format:"%.1f", Double(position)/100)
}
