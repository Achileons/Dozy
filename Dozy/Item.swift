//
//  Item.swift
//  Dozy
//
//  Created by Arda Agovic on 7.09.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
