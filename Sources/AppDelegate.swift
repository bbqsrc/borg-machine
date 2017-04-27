//
//  AppDelegate.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 30/3/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import RxSwift

enum BorgNotifications: String {
    case backupCompleted = "BorgMachine.BackupCompleted"
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let bag = DisposeBag()
    
    static weak var instance: AppDelegate!
    
    var window: NSWindow? = nil
    var systemMenuController: SystemMenuController!
    
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
        
        NSApp.mainMenu = NSMenu.loadFromNib(named: "MainMenu")
        
        WindowWatcher.onWindowsChanged = { NSApp.setActivationPolicy($0.isEmpty ? .accessory : .regular) }
        systemMenuController = SystemMenuController()
        
        if AppPreferences.main.value.repositoryPath == nil {
            OnboardingController.inWindow().show(self)
        }
        
        defer {
            // Wake up services
            _ = BackupService.instance
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
    }
}

extension AppDelegate: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        print(notification)
    }
    
    private func showSummaryAlert(_ data: [String: Any]) {
        let alert = NSAlert()
        alert.informativeText = "\(data)"
        alert.runModal()
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        guard let id = notification.userInfo?["id"] as? String else { return }
        
        if id == BorgNotifications.backupCompleted.rawValue {
            showSummaryAlert(notification.userInfo!["payload"] as! [String: Any])
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
