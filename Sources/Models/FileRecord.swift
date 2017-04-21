//
//  FileRecord.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

extension Int32: DefaultConvertible {}
extension UIntMax: DefaultConvertible {}

struct FileRecord: Mappable {
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
    
    init(map: Mapper) throws {
        flags = map.optionalFrom("flags")
        try gid = map.from("gid")
        try group = map.from("group")
        try healthy = map.from("healthy")
        try isomtime = map.from("isomtime")
        try linktarget = map.from("linktarget")
        try mode = map.from("mode")
        try path = map.from("path")
        try size = map.from("size")
        try source = map.from("source")
        try nodeType = map.from("type")
        try uid = map.from("uid")
        try user = map.from("user")
    }
}
