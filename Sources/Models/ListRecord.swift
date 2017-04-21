//
//  ListRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

struct ListRecord {
    let archives: [ArchiveRecord]
    let encryptionMode: String?
    let repository: RepositoryRecord
    
    init?(json data: [String: Any]) {
        guard let archives = data["archives"] as? [[String: String]] else { return nil }
        guard let repository = data["repository"] as? [String: String] else { return nil }
        guard let id = repository["id"], let lastModified = repository["last_modified"], let location = repository["location"] else {
            return nil
        }
        
        self.archives = archives.flatMap {
            if let archive = $0["archive"],
                let barchive = $0["barchive"],
                let id = $0["id"],
                let name = $0["name"],
                let start = $0["start"],
                let time = $0["time"] {
                return ArchiveRecord(archive: archive, barchive: barchive, id: id, name: name, start: start, time: time)
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
