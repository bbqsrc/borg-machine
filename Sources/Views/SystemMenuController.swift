//
//  SystemMenuController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 2/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

enum SystemMenuState {
    case cancellingBackup
    case backingUp(info: String?)
    case idleWithHistory(repository: String, time: String)
    case noConfiguration
}

class SystemMenuController {
    let menu = NSMenu()
    let statusItem: NSStatusItem

    var lastState: SystemMenuState = .noConfiguration {
        willSet {
            onStateChange(newValue)
        }
    }
    
    let primaryInfoItem = NSMenuItem(title: "")
    let secondaryInfoItem = NSMenuItem(title: "")
    
    let backupNowItem = NSMenuItem(
        title: "Back Up Now",
        action: #selector(AppDelegate.backUpNowTapped(_:))
    )
    
    let prefsItem = NSMenuItem(
        title: "Open Borg Machine Preferences…",
        action: #selector(AppDelegate.preferencesTapped(_:))
    )
    
    func onStateChange(_ state: SystemMenuState) {
        backupNowItem.isEnabled = true
        backupNowItem.title = "Back Up Now"
        
        switch state {
        case let .backingUp(info):
            backupNowItem.title = "Cancel This Backup"
            primaryInfoItem.title = "Backing Up…"
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
        
        let items = [
            primaryInfoItem,
            secondaryInfoItem,
            NSMenuItem.separator(),
            backupNowItem,
            NSMenuItem.separator(),
            prefsItem
        ]
            
        items.forEach(menu.addItem)
        
        onStateChange(lastState)
        
        statusItem.menu = menu
    }
}
