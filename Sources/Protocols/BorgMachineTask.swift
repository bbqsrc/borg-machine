//
//  BorgMachineTask.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 3/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

enum TaskState {
    case notStarted
    case starting
    case running
    case cancelling
    case finished
}

protocol BorgMachineTask: class {
    associatedtype T
    
    var state: TaskState { get set }
    var task: BufferedStringSubprocess { get }
    
    func run(onProgress: @escaping (T) -> ())
}

extension BorgMachineTask {
    func start(onProgress: @escaping (T) -> (), onSuccess: (() -> ())? = nil, onFailure: ((Int32) -> ())? = nil, onExit: (() -> ())? = nil) {
        if state != .notStarted {
            preconditionFailure("Process has already been started.")
        }
        
        state = .starting
        
        DispatchQueue.global(qos: .background).async {
            self.run(onProgress: onProgress)
            self.state = .finished
            
            if self.task.exitCode == 0 {
                onSuccess?()
            } else {
                onFailure?(self.task.exitCode)
            }
            
            DispatchQueue.main.async {
                onExit?()
            }
        }
    }
    
    func cancel() {
        if !task.isRunning {
            state = .finished
            return
        }
        
        task.terminate()
        state = .cancelling
    }
}
