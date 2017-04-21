//
//  ArchiveFileController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 4/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class ArchiveFileController: ViewController<ArchiveFileView>, NSOutlineViewDelegate, NSOutlineViewDataSource {
    private let archive: ArchiveListRecord
    private let tree: Node<FileRecord>
    private let info: InfoArchiveRecord
    
    let borg = BorgWrapper(preferences: AppPreferences)!
    
    static func inWindow(info: InfoArchiveRecord, archive: ArchiveListRecord) -> NSWindowController {
        let window = NSWindow(contentViewController: ArchiveFileController(info: info, archive: archive))
        let ctrl = NSWindowController(window: window)
        
        window.title = info.name
        
        return ctrl
    }
    
    init(info: InfoArchiveRecord, archive: ArchiveListRecord) {
        self.info = info
        self.archive = archive
        self.tree = parseNodes(archive)
        
        super.init()
        
        contentView.outlineView.menu = NSMenu()
        contentView.outlineView.menu?.addItem(withTitle: "Extract", action: #selector(extract(_:)), keyEquivalent: "e")
    }
    
    func runExtraction(paths: [String], outputDir: URL) {
        let process = borg.extract(archive: info.name, paths: paths, outputDirectory: outputDir.path)
        
        process.onComplete = {
            NSWorkspace.shared().open(outputDir)
        }
        
        process.launch()
        process.waitUntilExit()
    }
    
    func extract(_ sender: NSObject) {
        let items = contentView.outlineView.selectedRowIndexes.map(
            contentView.outlineView.item(atRow:)
        ) as! [Node<FileRecord>]
        let paths = items.flatMap({ $0.value }).map({ $0.path })
        
        let dialog = NSOpenPanel()
        
        dialog.title = "Select Output Path"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.canCreateDirectories = true
        
        if dialog.runModal() == NSModalResponseOK {
            if let outputDir = dialog.url {
                runExtraction(paths: paths, outputDir: outputDir)
            }
        }
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
            return record.logicalChildren[index]
        }
        
        return tree.logicalChildren[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? Node<FileRecord> {
            return item.logicalChildren.count > 0
        }
        
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? Node<FileRecord> {
            return item.logicalChildren.count
        }
        
        return tree.logicalChildren.count
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

fileprivate class Node<T>: CustomDebugStringConvertible {
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
        
        while let p = cur, let parent = p.parent {
            if p.value != nil || p.baseName == "/" || parent.logicalChildren.contains(where: { $0 === p }) {
                break
            }
            
            chunks.append(p.baseName)
            cur = parent
        }
        
        return chunks.reversed().joined(separator: "/")
    }
    
    private var firstValued: Node<T>? {
        // If has a value in and of itself, is a valid leaf
        if self.value != nil {
            return self
        }
        
        // If have more than 1 child, is a valid junction
        if order.count > 1 {
            return self
        }
        
        // Only one child, continue the dance
        if order.count == 1 {
            return self.order[0].firstValued
        }
        
        return nil
    }
    
    lazy var logicalChildren: [Node<T>] = {
        return self.order.flatMap { $0.firstValued }
    }()
    
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

fileprivate func parseNodes(_ archive: ArchiveListRecord) -> Node<FileRecord> {
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
