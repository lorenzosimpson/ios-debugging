//
//  EntryConforming.swift
//  JournalCoreData
//
//  Created by Spencer Curtis on 8/14/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation

protocol EntryConforming {
    
    var title: String? { get set }
    var bodyText: String? { get set }
    var mood: String? { get set }
    var timestamp: Date? { get set }
    var id: String? { get set }
}
