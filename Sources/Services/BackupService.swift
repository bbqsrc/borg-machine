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
    case backingUp(info: String?)
    case idleWithHistory(repository: String, time: String)
    case noConfiguration
}

class BackupService {
    static let instance = BackupService()
    
    private(set) var currentBackupTask: BackupTask? = nil
    let state = Variable<BackupState>(.noConfiguration)
    
    private func idleState() {
        ListTask().start(onProgress: { [weak self] repoName, time in
            self?.state.value = .idleWithHistory(repository: repoName, time: time)
        })
    }
    
    func cancel() {
        currentBackupTask?.cancel()
    }
    
    func startManualBackup() {
        guard let targetPaths = AppPreferences.main.targetPaths else {
            return
        }
        
        if let task = currentBackupTask, task.state != .finished {
            preconditionFailure("A backup task is already in progress.")
        }
        
        currentBackupTask = BackupTask.manual(paths: targetPaths)
        
        currentBackupTask?.start(
            onProgress: { [weak self] msg in
                self?.state.value = .backingUp(info: msg)
            },
            onExit: { [weak self] in
                self?.idleState()
            }
        )
    }
    
    private func scheduleBackupEvents() {
        
    }
    
    private init() {
        scheduleBackupEvents()
        
        if AppPreferences.main.repositoryPath != nil {
            idleState()
        }
    }
}
