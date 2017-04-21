//
//  ArchiveListRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct ArchiveListRecord: Mappable {
    let items: [FileRecord]
    
    init(map: Mapper) throws {
        try items = map.from("items")
    }
}
