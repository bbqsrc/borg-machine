//
//  ArchiveListRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

struct ArchiveListRecord {
    let items: [FileRecord]
    
    init?(json data: [String: Any]) {
        guard let items = data["items"] as? [[String: Any]] else { return nil }
        
        self.items = items.flatMap { x in
            guard let gid = x["gid"] as? Int32,
                let group = x["group"] as? String,
                let healthy = x["healthy"] as? Bool,
                let isomtime = x["isomtime"] as? String,
                let linktarget = x["linktarget"] as? String,
                let mode = x["mode"] as? String,
                let path = x["path"] as? String,
                let size = x["size"] as? UIntMax,
                let source = x["source"] as? String,
                let nodeType = x["type"] as? String,
                let uid = x["uid"] as? Int32,
                let user = x["user"] as? String else {
                    return nil
            }
            
            return FileRecord(flags: x["flags"] as? String, gid: gid, group: group, healthy: healthy, isomtime: isomtime, linktarget: linktarget, mode: mode, path: path, size: size, source: source, nodeType: nodeType, uid: uid, user: user)
        }
    }
}
