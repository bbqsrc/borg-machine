//
//  ListTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class ListTask: BorgMachineTask {
    typealias T = (String, String)
    
    var state = TaskState.notStarted
    let task: BufferedStringSubprocess
    
    init(archive archiveName: String? = nil, preferences: _AppPreferences = AppPreferences) {
        let borg = BorgWrapper(preferences: preferences)!
        
        task = borg.list(archive: archiveName)
    }
    
    func run(onProgress: @escaping (T) -> ()) {
        task.launch()
        state = .running
        
        task.waitUntilExit()
        
        if let data = task.outputJSON {
            guard let repository = data["repository"] as? [String: Any] else { return }
            guard let repoName = repository["location"] as? String else { return }
            guard let archives = data["archives"] as? [[String: Any]] else { return }
            guard let time = archives.last?["time"] as? String else { return }
            
            DispatchQueue.main.async {
                onProgress((repoName, time))
            }
        }
    }
}
