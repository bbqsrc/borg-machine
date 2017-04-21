//
//  InfoArchiveStatsRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct InfoArchiveStatsRecord: Mappable {
    let compressedSize: UIntMax
    let deduplicatedSize: UIntMax
    let fileCount: UIntMax
    let originalSize: UIntMax
    
    init(map: Mapper) throws {
        try compressedSize = map.from("compressed_size")
        try deduplicatedSize = map.from("deduplicated_size")
        try fileCount = map.from("nfiles")
        try originalSize = map.from("original_size")
    }
}
