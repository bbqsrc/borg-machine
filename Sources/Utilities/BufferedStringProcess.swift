//
//  BufferedStringProcess.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 21/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class BufferedStringSubprocess {
    private let task = Process()
    
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    
    private var progressBuf = ""
    private var outputBuf = ""
    
    var onLogProgress: ((String) -> ())?
    var onLogOutput: ((String) -> ())?
    var onComplete: (() -> ())?
    
    init(_ launchPath: String, arguments: [String], environment: [String: String]? = nil) {
        task.standardInput = stdin
        task.standardOutput = stdout
        task.standardError = stderr
        
        task.launchPath = launchPath
        task.arguments = arguments
        task.environment = environment
        
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let `self` = self else { return }
            
            self.progressBuf += String(data: handle.availableData, encoding: .utf8)!
        }
        
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let `self` = self else { return }
            
            self.outputBuf += String(data: handle.availableData, encoding: .utf8)!
            
            var lines = self.outputBuf.components(separatedBy: "\n")
            
            if let output = self.onLogOutput, lines.count > 1 {
                self.outputBuf = lines.popLast()!
                
                lines.forEach(output)
            }
        }
        
        task.terminationHandler = { [weak self] _ in
            guard let `self` = self else { return }
            
            if self.exitCode == 0 {
                self.onComplete?()
            }
            
            // Avoids memory leaks.
            self.onLogOutput = nil
            self.onLogProgress = nil
            self.onComplete = nil
        }
    }
    
    var currentDirectoryPath: String {
        get { return task.currentDirectoryPath }
        set { task.currentDirectoryPath = newValue }
    }
    
    var exitCode: Int32 {
        return task.terminationStatus
    }
    
    var isRunning: Bool {
        return task.isRunning
    }
    
    var output: String {
        return progressBuf
    }
    
    var outputJSON: [String: Any]? {
        return JSONSerialization.jsonDict(with: progressBuf.data(using: .utf8)!)
    }
    
    func launch() {
        task.launch()
    }
    
    func terminate() {
        task.terminate()
    }
    
    func waitUntilExit() {
        task.waitUntilExit()
    }
    
    func write(string: String, withNewline: Bool = true) {
        let handle = stdin.fileHandleForWriting
        handle.write(string.data(using: .utf8)!)
        
        if withNewline {
            handle.write("\n".data(using: .utf8)!)
        }
    }
}
