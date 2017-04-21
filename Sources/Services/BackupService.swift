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
    
    private(set) var currentBackupTask: BackupTask? = nil
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
                self?.state.value = .backingUp(percent: msg.0, info: msg.1)
            },
            onExit: { [weak self] in
                self?.idleState()
                
                self?.currentBackupTask = nil
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
