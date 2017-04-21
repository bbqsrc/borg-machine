//
//  BackupTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class BackupTask: BorgMachineTask {
    typealias T = String
    
    var state: TaskState = .notStarted
    let task: BufferedStringSubprocess
    
    static func manual(paths: [String]) -> BackupTask {
        let archiveName = "BorgMachine-Manual-\(Date().iso8601String())"
        
        return BackupTask(
            archive: archiveName,
            paths: paths
        )
    }
    
    init(archive archiveName: String, paths targetPaths: [String], preferences: _AppPreferences = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        
        task = borg.create(
            archive: archiveName,
            paths: targetPaths
        )
    }
    
    private func dispatchNotification() {
        if let output = task.outputJSON {
            let n = NSUserNotification()
            n.soundName = NSUserNotificationDefaultSoundName
            n.hasActionButton = true
            n.userInfo = [
                "id": BorgNotifications.backupCompleted.rawValue,
                "payload": output
            ]
            
            guard let archive = output["archive"] as? [String: Any] else {
                return
            }
            let archiveName = archive["name"] as? String ?? "<unknown>"
            
            n.title = "Backup Completed"
            n.informativeText = archiveName
            n.actionButtonTitle = "More Info"
            
            NSUserNotificationCenter.default.scheduleNotification(n)
            
            //NSUserNotificationCenter.default.deliver(n)
        }
    }
    
    private func parseMessage(json: [String: Any]) -> String? {
        guard let type = json["type"] as? String else { return nil }
        
        switch type {
        case "archive_progress":
            if let path = json["path"] as? String, path != "" {
                return "File: \(path)"
            } else {
                return "Archiving…"
            }
        default:
            return json["message"] as? String
        }
    }
    
    func run(onProgress: @escaping (String) -> ()) {
        task.onLogOutput = { [weak self] line in
            guard let json = JSONSerialization.jsonDict(with: line.data(using: .utf8)!) else { return }
            guard let msg = self?.parseMessage(json: json) else { return }
            
            DispatchQueue.main.async {
                onProgress(msg)
            }
        }
        
        task.launch()
        state = .running
        
        task.waitUntilExit()
        dispatchNotification()
    }
}
