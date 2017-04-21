//
//  InfoArchiveStatsRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

struct InfoArchiveStatsRecord {
    let compressedSize: UIntMax
    let deduplicatedSize: UIntMax
    let fileCount: UIntMax
    let originalSize: UIntMax
}
