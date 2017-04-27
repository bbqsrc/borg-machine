//
//  MainPreferences.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 25/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct MainPreferences: Mappable {
    var repositoryPath: String? = nil
    var repositoryType: String? = nil
    var targetPaths: [String] = []
    var passphrase: String? = nil
    var schedule: [ScheduleRule] = []
    
    init(map: Mapper) throws {
        repositoryPath = map.optionalFrom("repositoryPath")
        repositoryType = map.optionalFrom("repositoryType")
        targetPaths = map.optionalFrom("targetPaths") ?? []
        passphrase = map.optionalFrom("passphrase")
        schedule = map.optionalFrom("schedule") ?? []
    }
    
    init() {}
}
