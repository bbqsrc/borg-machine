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

fileprivate let backgroundProcessingQueue = DispatchQueue(label: "BorgMachine.BackgroundQueue", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: nil)

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    var window: NSWindow? = nil
    var systemMenuController: SystemMenuController!
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        print(notification)
    }
    
    func showSummaryAlert(_ data: [String: Any]) {
        let alert = NSAlert()
        
        alert.informativeText = "\(data)"
        
        alert.runModal()
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.identifier == BorgNotifications.backupCompleted.rawValue {
            showSummaryAlert(notification.userInfo!)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wake up services
        _ = BackupService.instance
        
        NSUserNotificationCenter.default.delegate = self
        
        systemMenuController = SystemMenuController()
        
        if AppPreferences.main.repositoryPath == nil {
            let window = NSWindow(contentViewController: OnboardingController())
            let ctrl = NSWindowController(window: window)
            
            self.window = window
            
            ctrl.showWindow(self)
            return
        }
        
        updateMenuToIdleState()
    }
    
    func updateMenuToIdleState() {
        //backgroundProcessingQueue.async {
        DispatchQueue.global(qos: .background).async {
            let borg = BorgWrapper(preferences: AppPreferences)!
            
            let task = borg.list()
            task.waitUntilExit()
            
            if let data = task.outputJSON {
                guard let repository = data["repository"] as? [String: Any] else { return }
                guard let repoName = repository["location"] as? String else { return }
                guard let archives = data["archives"] as? [[String: Any]] else { return }
                guard let time = archives.last?["time"] as? String else { return }
                
                DispatchQueue.main.async { [weak self] in
                    self?.systemMenuController.lastState = .idleWithHistory(repository: repoName, time: time)
                }
            }
        }
    }
    
    var currentBackupTask: BufferedStringSubprocess? = nil
    
    func backUpNowTapped(_ sender: NSObject) {
        guard let wrapper = BorgWrapper(preferences: AppPreferences),
            let targetPaths = AppPreferences.main.targetPaths else {
                return
        }
        
        if let task = currentBackupTask {
            // Do cancel
            task.terminate()
            systemMenuController.lastState = .cancellingBackup
            
            backgroundProcessingQueue.async {
                task.waitUntilExit()
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateMenuToIdleState()
                }
            }
            
            return
        }
        
        let archiveName = "BorgMachine-Manual-\(Date().iso8601String())"
        
        backgroundProcessingQueue.async { [weak self] in
            let task = wrapper.create(
                archive: archiveName,
                paths: targetPaths
            )
            
            self?.currentBackupTask = task
            
            task.onLogOutput = { [weak self] line in
                guard let json = JSONSerialization.jsonDict(with: line.data(using: .utf8)!) else { return }
                guard let type = json["type"] as? String else { return }
                
                var msg: String? = nil
                
                switch type {
                case "archive_progress":
                    if let path = json["path"] as? String, path != "" {
                        msg = "File: \(path)"
                    } else {
                        print(json)
                        msg = "Archiving…"
                    }
                default:
                    msg = json["message"] as? String
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.systemMenuController.lastState = .backingUp(info: msg)
                }
            }
            
            task.waitUntilExit()
            
            if let output = task.outputJSON {
                let n = NSUserNotification()
                n.soundName = NSUserNotificationDefaultSoundName
                n.hasActionButton = true
                n.identifier = BorgNotifications.backupCompleted.rawValue
                n.userInfo = output
                
                guard let archive = output["archive"] as? [String: Any] else {
                    return
                }
                let archiveName = archive["name"] as? String ?? "<unknown>"
                
                n.informativeText = "Backup \(archiveName) Completed"
                n.actionButtonTitle = "More Info"
                
                NSUserNotificationCenter.default.deliver(n)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMenuToIdleState()
            }
            
            self?.currentBackupTask = nil
        }
    }
    
    func preferencesTapped(_ sender: NSObject) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            let window = NSWindow(contentViewController: OnboardingController())
            let ctrl = NSWindowController(window: window)
            
            self.window = window
            
            ctrl.showWindow(self)
        }
        
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

