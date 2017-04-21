//
//  InfoArchiveRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct InfoArchiveRecord: Mappable {
    let id: String
    let name: String
    let start: String
    let end: String
    let stats: InfoArchiveStatsRecord
    
    init(map: Mapper) throws {
        try id = map.from("id")
        try name = map.from("name")
        try start = map.from("start")
        try end = map.from("end")
        try stats = map.from("stats")
    }
}
