//
//  BackupTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class BackupTask: BorgMachineTask {
    typealias T = (String, String?)
    
    var state: TaskState = .notStarted
    let task: BufferedStringSubprocess
    let fileCount: Int64
    var currentPercent: String = "0.00%"
    
    static func manual(paths: [String]) -> BackupTask {
        let archiveName = "BorgMachine-Manual-\(Date().iso8601String())"
        
        return BackupTask(
            archive: archiveName,
            paths: paths
        )
    }
    
    init(archive archiveName: String, paths targetPaths: [String], preferences: _AppPreferences = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        
        fileCount = try! targetPaths
            .map({ URL(string: $0)! })
            .map(FileManager.default.countFilesRecursive(at:))
            .reduce(0, { $0 + $1 })
        
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
        }
    }
    
    private func parseMessage(json: [String: Any]) -> (String, String?) {
        guard let type = json["type"] as? String else {
            return (currentPercent, nil)
        }
        
        let msg: String?
        
        switch type {
        case "archive_progress":
            if let path = json["path"] as? String, path != "" {
                msg = "File: \(path)"
            } else {
                msg = "Archiving…"
            }
        default:
            msg = json["message"] as? String
        }
        
        if let nfiles = json["nfiles"] as? Int64 {
            let pc = (Double(nfiles) / Double(fileCount)) * 100.0
            currentPercent = String(format: "%.2f%%", pc)
        }
        
        return (currentPercent, msg)
    }
    
    func run(onProgress: @escaping (String, String?) -> ()) {
        task.onLogOutput = { [weak self] line in
            guard let json = JSONSerialization.jsonDict(with: line.data(using: .utf8)!) else { return }
            guard let msg = self?.parseMessage(json: json) else { return }
            
            DispatchQueue.main.async {
                onProgress(msg.0, msg.1)
            }
        }
        
        task.launch()
        state = .running
        
        task.waitUntilExit()
        dispatchNotification()
    }
}
