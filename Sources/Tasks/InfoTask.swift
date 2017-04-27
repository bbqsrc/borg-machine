//
//  InfoTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class InfoTask: BorgMachineTask {
    let task: BufferedStringSubprocess
    var state: TaskState = .notStarted
    
    init(archive: String? = nil, preferences: AppPreferencesImpl = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        
        task = borg.info(archive: archive)
    }
    
    init(all: Bool, preferences: AppPreferencesImpl = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        
        task = borg.info(all: all)
    }
    
    func run(onProgress: @escaping (InfoRecord) -> ()) {
        task.launch()
        state = .running
        
        task.waitUntilExit()
        
        if let data = task.outputJSON, let record = InfoRecord.from(data) {
            DispatchQueue.main.async {
                onProgress(record)
            }
        }
    }
}
