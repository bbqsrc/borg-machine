//
//  ArchiveRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct ArchiveRecord: Mappable {
    let archive: String
    let barchive: String
    let id: String
    let name: String
    let start: String
    let time: String
    
    init(map: Mapper) throws {
        try archive = map.from("archive")
        try barchive = map.from("barchive")
        try id = map.from("id")
        try name = map.from("name")
        try start = map.from("start")
        try time = map.from("time")
    }
}
