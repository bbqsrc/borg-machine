//
//  InfoRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct InfoRecord: Mappable {
    let archives: [InfoArchiveRecord]
    let encryptionMode: String?
    let repository: RepositoryRecord
    
    init(map: Mapper) throws {
        try archives = map.from("archives")
        encryptionMode = map.optionalFrom("encryption.mode")
        try repository = map.from("repository")
    }
}
