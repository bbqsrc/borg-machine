//
//  SystemMenuController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 2/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import RxSwift

class SystemMenuController {
    let bag = DisposeBag()
    
    let menu = NSMenu()
    let statusItem: NSStatusItem
    
    let primaryInfoItem = NSMenuItem(title: "")
    let secondaryInfoItem = NSMenuItem(title: "")
    
    @objc func backUpNowTapped(_ sender: NSObject) {
        BackupService.instance.startManualBackup()
    }
    
    @objc func preferencesTapped(_ sender: NSObject) {
        DispatchQueue.main.async {
            OnboardingController.inWindow().show(self)
        }
    }
    
    @objc func viewArchivesTapped(_ sender: NSObject) {
        DispatchQueue.main.async {
            ArchiveListController.inWindow().show(self)
        }
    }
    
    let backupNowItem = NSMenuItem(
        title: "Back Up Now",
        action: #selector(backUpNowTapped(_:))
    )
    
    let prefsItem = NSMenuItem(
        title: "Open Borg Machine Preferences…",
        action: #selector(preferencesTapped(_:))
    )
    
    let repoInfoItem = NSMenuItem(
        title: "View Archives…",
        action: #selector(viewArchivesTapped(_:))
    )
    
    let quitItem = NSMenuItem(
        title: "Quit Borg Machine",
        target: NSApp,
        action: #selector(NSApp.terminate(_:))
    )
    
    func onStateChange(_ state: BackupState) {
        backupNowItem.isEnabled = true
        backupNowItem.title = "Back Up Now"
        
        switch state {
        case let .backingUp(percent, info):
            backupNowItem.title = "Cancel This Backup"
            primaryInfoItem.title = "Backing Up… \(percent)"
            secondaryInfoItem.isHidden = info == nil

            if let info = info {
                secondaryInfoItem.title = info
            }
        case .noConfiguration:
            primaryInfoItem.title = "Borg Machine is not configured."
            secondaryInfoItem.isHidden = true
            backupNowItem.isEnabled = false
        case let .idleWithHistory(repository, time):
            primaryInfoItem.title = "Latest Backup to \(repository)"
            secondaryInfoItem.title = time
            secondaryInfoItem.isHidden = false
        case .cancellingBackup:
            primaryInfoItem.title = "Cancelling Backup…"
            secondaryInfoItem.isHidden = true
            backupNowItem.isEnabled = false
        }
    }
    
    init() {
        statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
        
        let image = NSImage(named: "backupIcon")!
        statusItem.image = image
        
        let items: [NSMenuItem] = [
            primaryInfoItem,
            secondaryInfoItem,
            .separator(),
            backupNowItem,
            repoInfoItem,
            .separator(),
            prefsItem,
            .separator(),
            quitItem
        ]
            
        items.forEach {
            menu.addItem($0)
            if $0.target == nil {
                $0.target = self
            }
        }
        
        statusItem.menu = menu
        
        BackupService.instance.state.asObservable()
            .subscribe(onNext: {
                [weak self] in self?.onStateChange($0)
            }) => bag
    }
}
