//
//  ArchiveFileController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 4/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

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

class Node<T>: CustomDebugStringConvertible {
    fileprivate(set) var baseName: String
    fileprivate(set) var value: T? = nil
    private(set) var children = [String: Node<T>]()
    private(set) var order = [Node<T>]()
    
    weak var parent: Node<T>? = nil
    
    init(_ value: T?, name: String, parent: Node<T>?) {
        self.baseName = name
        self.value = value
        self.parent = parent
    }
    
    var name: String {
        var chunks = [baseName]
        
        var cur = parent
        
        while let p = cur {
            if p.value != nil || p.children.count > 1 || p.baseName == "/" {
                break
            }
            
            chunks.append(p.baseName)
            cur = p.parent
        }
        
        return chunks.reversed().joined(separator: "/")
    }
    
    var firstValued: Node<T>? {
        if order.isEmpty {
            return nil
        }
        
        if order[0].children.count == 1 && order[0].value == nil {
            return order[0].firstValued
        } else {
            return self
        }
    }
    
    subscript(path: String) -> Node<T>? {
        get {
            return children[path]
        }
        set {
            if let v = newValue {
                children[path] = v
                order.append(v)
            } else if let v = children.removeValue(forKey: path) {
                if let i = order.index(where: { $0 === v }) {
                    order.remove(at: i)
                }
            }
        }
    }
    
    subscript(_ value: Int) -> Node<T>? {
        get {
            return order[value]
        }
    }
    
    var count: Int {
        return children.count
    }
    
    var debugDescription: String {
        return "(\(value as Any), \(children))"
    }
}

func parseNodes(_ archive: ArchiveListRecord) -> Node<FileRecord> {
    let root = Node<FileRecord>(nil, name: "/", parent: nil)
    
    for item in archive.items {
        let components = item.path.components(separatedBy: "/")
        
        var cur = root
        
        for c in components {
            if cur[c] == nil {
                cur[c] = Node(nil, name: c, parent: cur)
            }
            
            cur = cur[c]!
        }
        
        cur.value = item
    }
    
    return root
}

class ArchiveFileController: ViewController<ArchiveFileView>, NSOutlineViewDelegate, NSOutlineViewDataSource {
    let archive: ArchiveListRecord
    let tree: Node<FileRecord>
    
    init(archive: ArchiveListRecord) {
        self.archive = archive
        self.tree = parseNodes(archive)
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear() {
        contentView.outlineView.delegate = self
        contentView.outlineView.dataSource = self
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let record = item as? Node<FileRecord> {
            return record.firstValued![index]!
        }
        
        return tree.firstValued![index]!
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? Node<FileRecord> {
            return (item.firstValued?.count ?? 0) > 0
        }
        
        return false
    }
    
    /*
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if let item = item as? Node<FileRecord> {
            return item.value
        }
        
        return nil
    }
    */
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? Node<FileRecord> {
            return item.firstValued?.count ?? 0
        }
        
        return tree.firstValued?.count ?? 0
    }
    
    private lazy var folderIcon: NSImage = {
        return NSWorkspace.shared().icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
    }()
    
    private func getIcon(for record: FileRecord) -> NSImage {
        let workspace = NSWorkspace.shared()
        
        if record.nodeType == "d" {
            return folderIcon
        }
        
        let fileType = record.path
            .components(separatedBy: "/").last!
            .components(separatedBy: ".").last!
        
        return workspace.icon(forFileType: fileType)
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let item = item as! Node<FileRecord>
        guard let column = tableColumn else { return nil }
        
        let cell = outlineView.make(withIdentifier: column.identifier, owner: self) as! NSTableCellView
        
        switch column.identifier {
        case "name":
            if let record = item.value {
                cell.imageView?.image = getIcon(for: record)
            } else {
                cell.imageView?.image = folderIcon
            }
            
            cell.textField?.stringValue = item.name
        case "size":
            if let value = item.value, value.nodeType == "-" {
                cell.textField?.stringValue = ByteCountFormatter().string(fromByteCount: Int64(value.size))
            } else {
                cell.textField?.stringValue = "--"
            }
        case "dateModified":
            cell.textField?.stringValue = item.value?.isomtime ?? "--"
        default:
            return nil
        }
        
        return cell
    }
}
