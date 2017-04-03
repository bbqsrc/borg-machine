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
    
    @objc func backUpNowTapped(_ sender: NSObject) {
        BackupService.instance.startManualBackup()
    }
    
    @objc func preferencesTapped(_ sender: NSObject) {
        AppDelegate.instance.showOnboardingWindow()
    }
    
    func showSummaryAlert(_ data: [String: Any]) {
        let alert = NSAlert()
        alert.informativeText = "\(data)"
        alert.runModal()
    }
    
    func showOnboardingWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            let window = NSWindow(contentViewController: OnboardingController())
            let ctrl = NSWindowController(window: window)
            
            self.window = window
            
            ctrl.showWindow(self)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        NSUserNotificationCenter.default.delegate = self
        
        // Wake up services
        _ = BackupService.instance
        
        systemMenuController = SystemMenuController()
        
        if AppPreferences.main.repositoryPath == nil {
            showOnboardingWindow()
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
