//
//  ArchiveListController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import RxSwift

class ArchiveListViewModel {
    let listRecord = Variable<InfoRecord?>(nil)
}

class ArchiveListController: ViewController<ArchiveListView>, NSTableViewDelegate, NSTableViewDataSource {
    var bag = DisposeBag()
    let viewModel = ArchiveListViewModel()
    
    static func inWindow() -> NSWindowController {
        let window = NSWindow(contentViewController: ArchiveListController())
        let ctrl = NSWindowController(window: window)
        
        window.title = "Backup Archives"
        
        return ctrl
    }
    
    override func viewDidLoad() {
        InfoTask(all: true).start(onProgress: { [weak self] in
            self?.viewModel.listRecord.value = $0
        })
    }
    
    var window: NSWindow? = nil
    
    func onDoubleTapRow(_ sender: NSTableView) {
        guard let info = viewModel.listRecord.value?.archives[sender.clickedRow] else { return }
        
        ListTask(archive: info.name).start(onProgress: { [weak self] archive in
            guard let `self` = self else { return }
            
            ArchiveFileController.inWindow(info: info, archive: archive).show(self)
        })
    }
    
    override func viewWillAppear() {
        viewModel.listRecord.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.contentView.tableView.reloadData()
            }) => bag
        
        contentView.tableView.delegate = self
        contentView.tableView.dataSource = self
    
        contentView.tableView.doubleAction = #selector(ArchiveListController.onDoubleTapRow(_:))
    }
    
    override func viewWillDisappear() {
        bag = DisposeBag()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.listRecord.value?.archives.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        guard let archives = viewModel.listRecord.value?.archives else { return nil }
        
        let archive = archives[row]
        let cell = tableView.make(withIdentifier: column.identifier, owner: self) as! NSTableCellView
        
        switch column.identifier {
        case "name":
            cell.textField?.stringValue = archive.name
        case "time":
            cell.textField?.stringValue = archive.end
        case "files":
            cell.textField?.stringValue = "\(archive.stats.fileCount)"
        case "originalSize":
            cell.textField?.stringValue = ByteCountFormatter().string(fromByteCount: Int64(archive.stats.originalSize))
        case "deduplicatedSize":
            cell.textField?.stringValue = ByteCountFormatter().string(fromByteCount: Int64(archive.stats.deduplicatedSize))
        case "compressedSize":
            cell.textField?.stringValue = ByteCountFormatter().string(fromByteCount: Int64(archive.stats.compressedSize))
        default:
            break
        }
        
        return cell
    }
}
