//
//  AppDelegate.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 30/3/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

enum BorgNotifications: String {
    case backupCompleted = "BorgMachine.BackupCompleted"
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var instance: AppDelegate!
    
    var window: NSWindow? = nil
    var systemMenuController: SystemMenuController!
    
    func showSummaryAlert(_ data: [String: Any]) {
        let alert = NSAlert()
        alert.informativeText = "\(data)"
        alert.runModal()
    }
    
    private func singleInstanceCheck() {
        let id = Bundle.main.bundleIdentifier!
        let apps = NSWorkspace.shared().runningApplications.filter({ $0.bundleIdentifier == id })
        
        if apps.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Borg Machine is already running."
            alert.runModal()
            
            NSApp.terminate(self)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        singleInstanceCheck()
        
        AppDelegate.instance = self
        NSUserNotificationCenter.default.delegate = self
        
        // Wake up services
        _ = BackupService.instance
        
        systemMenuController = SystemMenuController()
        
        if AppPreferences.main.repositoryPath == nil {
            OnboardingController.inWindow().show(self)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
    }
}

extension AppDelegate: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        // print(notification)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.identifier == BorgNotifications.backupCompleted.rawValue {
            showSummaryAlert(notification.userInfo!)
        }
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
