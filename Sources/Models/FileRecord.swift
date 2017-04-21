//
//  FileRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

struct FileRecord {
    let flags: String?
    let gid: Int32
    let group: String
    let healthy: Bool
    let isomtime: String
    let linktarget: String
    let mode: String
    let path: String
    let size: UIntMax
    let source: String
    let nodeType: String
    let uid: Int32
    let user: String
}
