//
//  BorgWrapper.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Cocoa

enum RepoEncryption: String {
    case none = "none"
    case keyfile = "keyfile"
    case repokey = "repokey"
    case keyfileBlake2 = "keyfile-blake2"
    case repokeyBlake2 = "repokey-blake2"
    case authenticated = "authenticated"
}

enum ArchiveCompression: String {
    case lz4 = "lz4"
}

func questionPrompt(message: String) -> String {
    let alert = NSAlert()
    
    alert.addButton(withTitle: "Yes")
    alert.addButton(withTitle: "No")
    
    let response = alert.runModal()
    
    if response == 1000 {
        return "YES"
    } else {
        return "NO"
    }
}

class BorgWrapper {
    static let binPath = Bundle.main.path(forAuxiliaryExecutable: "borg")!
    
    private func run(_ arguments: [String]) -> BufferedStringSubprocess {
        return BufferedStringSubprocess(BorgWrapper.binPath, arguments: arguments)
    }
    
    func initialize(repoPath path: String, passphrase: String, encryption: RepoEncryption = .repokeyBlake2) -> BufferedStringSubprocess {
        let process = run(["init", "--log-json", "-e", encryption.rawValue, path])
        
        process.onLogOutput = { line in
            print(line)
            let json = try? JSONSerialization.jsonObject(with: line.data(using: .utf8)!, options: []) as! [String: Any]
            
            if let type = json?["type"] as? String {
                switch type {
                case "question_prompt":
                    DispatchQueue.main.async {
                        process.write(string: questionPrompt(message: json?["message"] as? String ?? ""))
                    }
                    
                case "log_message":
                    let alert = NSAlert()
                    
                    let level = json?["levelname"] as? String
                    
                    if level == "ERROR" {
                        alert.messageText = json?["message"] as? String ?? ""
                        alert.addButton(withTitle: "OK")
                        
                        DispatchQueue.main.async {
                            let response = alert.runModal()
                            print(response)
                        }
                    }
                    
                default:
                    break
                }
            }
        }
        
        process.launch()
        
        process.write(string: passphrase)
        process.write(string: passphrase)
        
        return process
    }
}

class BufferedStringSubprocess {
    private let task = Process()
    
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    
    private var buf = ""
    
    var onLogOutput: ((String) -> ())?
    
    init(_ launchPath: String, arguments: [String]) {
        task.standardInput = stdin
        task.standardOutput = stdout
        task.standardError = stderr
        
        task.launchPath = launchPath
        task.arguments = arguments
        
        stdout.fileHandleForReading.readabilityHandler = { [unowned self] handle in
            let out = String(data: handle.availableData, encoding: .utf8)!
            print(out)
        }
        
        stderr.fileHandleForReading.readabilityHandler = { [unowned self] handle in
            self.buf += String(data: handle.availableData, encoding: .utf8)!
            
            var lines = self.buf.components(separatedBy: "\n")
            
            if let output = self.onLogOutput, lines.count > 1 {
                self.buf = lines.popLast()!
                
                lines.forEach(output)
            }
        }
    }
    
    func launch() {
        task.launch()
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
