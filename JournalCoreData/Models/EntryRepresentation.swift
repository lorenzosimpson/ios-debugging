//
//  EntryRepresentation.swift
//  JournalCoreData
//
//  Created by Spencer Curtis on 8/14/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation

struct EntryRepresentation: Codable {
    var title: String?
    var bodyText: String?
    var mood: String?
    var timestamp: Date?
    var id: String?
}

func ==(lhs: EntryRepresentation, rhs: Entry) -> Bool {
    return rhs.title == lhs.title &&
        rhs.bodyText == lhs.bodyText &&
        rhs.mood == lhs.mood &&
        rhs.id == lhs.id
}

func ==(lhs: Entry, rhs: EntryRepresentation) -> Bool {
    return rhs == lhs
}

func !=(lhs: EntryRepresentation, rhs: Entry) -> Bool {
    return !(lhs == rhs)
}

func !=(lhs: Entry, rhs: EntryRepresentation) -> Bool {
    return rhs != lhs
}
