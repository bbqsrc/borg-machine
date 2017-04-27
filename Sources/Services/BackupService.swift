//
//  BackupService.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 2/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import RxSwift

enum BackupState {
    case cancellingBackup
    case backingUp(percent: String, info: String?)
    case idleWithHistory(repository: String, time: String)
    case noConfiguration
}

class BackupService {
    static let instance = BackupService()
    
    private let bag = DisposeBag()
    
    private(set) var currentBackupTask: BackupTask? = nil
    private let schedule = Scheduler()
    
    let state = Variable<BackupState>(.noConfiguration)
    
    private func idleState() {
        InfoTask().start(onProgress: { [weak self] record in
            let repository = record.repository.location
            let time = record.archives.last?.end ?? ""
            
            self?.state.value = .idleWithHistory(repository: repository, time: time)
        })
    }
    
    func cancel() {
        currentBackupTask?.cancel()
    }
    
    private func startTask() {
        currentBackupTask?.start(
            onProgress: { [weak self] msg in
                self?.state.value = .backingUp(percent: msg.0, info: msg.1)
            },
            onExit: { [weak self] in
                guard let `self` = self else { return }
                self.idleState()
                self.currentBackupTask = nil
            }
        )
    }
    
    func startManualBackup() {
        let targetPaths = AppPreferences.main.value.targetPaths
        
        if let task = currentBackupTask, task.state != .finished {
            preconditionFailure("A backup task is already in progress.")
        }
        
        currentBackupTask = BackupTask.manual(paths: targetPaths)
        startTask()
    }
    
    private func startScheduledBackup(date: Date, rule: RecurrenceRule) {
        let targetPaths = AppPreferences.main.value.targetPaths
        
        if let task = currentBackupTask, task.state != .finished {
            preconditionFailure("A backup task is already in progress.")
        }
        
        currentBackupTask = BackupTask.scheduled(paths: targetPaths, date: date, rule: rule)
        createBackupNotification(date: date, rule: rule)
        startTask()
    }
    
    private func createBackupNotification(date: Date, rule: RecurrenceRule) {
        let n = NSUserNotification()
        
        n.soundName = NSUserNotificationDefaultSoundName
        
        n.title = "Scheduled Backup Starting"
        n.informativeText = date.iso8601String()
        
        n.hasActionButton = true
        n.actionButtonTitle = "Stop Backup"
        
        NSUserNotificationCenter.default.deliver(n)
    }
    
    func scheduleBackupEvents(rules: [ScheduleRule]) {
        schedule.reset()
        
        for r in rules {
            let d = r.nextDate()!
            
            schedule.at(d) { date in
                self.startScheduledBackup(date: date, rule: r.rule)
                return r.nextDate()
            }
        }
    }
    
    private init() {
        if AppPreferences.main.value.repositoryPath != nil {
            idleState()
        }
        
        AppPreferences.main.asObservable()
            .map({ $0.schedule })
            .distinctUntilChanged({ $0 == $1 })
            .subscribe(onNext: { [weak self] rules in
                print("Scheduling \(rules.count) events.")
                self?.scheduleBackupEvents(rules: rules)
            }) => bag
    }
}
