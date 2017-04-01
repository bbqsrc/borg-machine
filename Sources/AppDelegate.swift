//
//  AppDelegate.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 30/3/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow? = nil
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
        
        let image = NSImage(named: "backupIcon")!
        statusItem.image = image
        statusItem.menu = generateMenu()
        
        if AppPreferences.main.repositoryPath == nil {
            let window = NSWindow(contentViewController: OnboardingController())
            let ctrl = NSWindowController(window: window)
            
            self.window = window
            
            ctrl.showWindow(self)
        }
    }
    
    func generateMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Current backup info
        let targetItem = NSMenuItem(title: "Latest Backup to <test>")
        let lastUpdateItem = NSMenuItem(title: "Today, 16:48")
        
        // Functionality
        let backupNowItem = NSMenuItem(
            title: "Back Up Now",
            action: #selector(AppDelegate.backUpNowTapped(_:))
        )
        let prefsItem = NSMenuItem(
            title: "Open Borg Machine preferences…",
            action: #selector(AppDelegate.preferencesTapped(_:))
        )
        
        menu.addItem(targetItem)
        menu.addItem(lastUpdateItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(backupNowItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(prefsItem)
        
        return menu
    }
    
    func backUpNowTapped(_ sender: NSObject) {
        
    }
    
    func preferencesTapped(_ sender: NSObject) {
        let window = NSWindow(contentViewController: PreferencesController())
        let ctrl = NSWindowController(window: window)
        
        self.window = window
        
        ctrl.showWindow(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
    }
}

class BorgMachine: NSApplication {
    private let appDelegate = AppDelegate()
    
    override init() {
        super.init()
        
        self.delegate = appDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

