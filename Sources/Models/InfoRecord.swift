//
//  InfoRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

struct InfoRecord {
    let archives: [InfoArchiveRecord]
    let encryptionMode: String?
    let repository: RepositoryRecord
    
    init?(json data: [String: Any]) {
        guard let archives = data["archives"] as? [[String: Any]] else { return nil }
        guard let repository = data["repository"] as? [String: String] else { return nil }
        guard let id = repository["id"], let lastModified = repository["last_modified"], let location = repository["location"] else {
            return nil
        }
        
        self.archives = archives.flatMap {
            if let id = $0["id"] as? String,
                let name = $0["name"] as? String,
                let start = $0["start"] as? String,
                let end = $0["end"] as? String,
                let statsData = $0["stats"] as? [String: UIntMax],
                let stats = genStats(statsData) {
                
                return InfoArchiveRecord(id: id, name: name, start: start, end: end, stats: stats)
            }
            
            return nil
        }
        
        self.repository = RepositoryRecord(id: id, lastModified: lastModified, location: location)
        
        if let encryption = data["encryption"] as? [String: Any], let encryptionMode = encryption["mode"] as? String {
            self.encryptionMode = encryptionMode
        } else {
            self.encryptionMode = nil
        }
    }
}

fileprivate func genStats(_ stats: [String: UIntMax]) -> InfoArchiveStatsRecord? {
    guard let compressedSize = stats["compressed_size"],
        let deduplicatedSize = stats["deduplicated_size"],
        let fileCount = stats["nfiles"],
        let originalSize = stats["original_size"] else {
            return nil
    }
    
    return InfoArchiveStatsRecord(compressedSize: compressedSize, deduplicatedSize: deduplicatedSize, fileCount: fileCount, originalSize: originalSize)
}
