//
//  ListTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class ListTask: BorgMachineTask {
    typealias T = ArchiveListRecord
    
    var state = TaskState.notStarted
    let task: BufferedStringSubprocess
    
    init(archive archiveName: String, preferences: AppPreferencesImpl = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        task = borg.list(archive: archiveName)
    }
    
    func run(onProgress: @escaping (ArchiveListRecord) -> ()) {
        task.launch()
        state = .running
        
        task.waitUntilExit()
        
        if let data = task.outputJSON, let record = ArchiveListRecord.from(data) {
            DispatchQueue.main.async {
                onProgress(record)
            }
        }
    }
}
