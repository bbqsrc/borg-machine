//
//  RepositoryRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct RepositoryRecord: Mappable {
    let id: String
    let lastModified: String
    let location: String
    
    init(map: Mapper) throws {
        try id = map.from("id")
        try lastModified = map.from("last_modified")
        try location = map.from("location")
    }
}
