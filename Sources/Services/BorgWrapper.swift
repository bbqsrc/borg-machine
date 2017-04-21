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

class BorgLogMessage {
    let json: [String: Any]
    
    var level: String {
        return json["levelname"] as? String ?? "INFO"
    }
    
    var message: String {
        let base = json["message"] as? String ?? ""
        
        return base.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(json: [String: Any]) {
        self.json = json
    }
    
    func showAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            
            switch self.level {
            case "ERROR":
                alert.alertStyle = .critical
                alert.messageText = "Borg Machine — Error"
            case "WARNING":
                alert.alertStyle = .warning
                alert.messageText = "Borg Machine — Warning"
            default:
                alert.alertStyle = .informational
                alert.messageText = "Borg Machine — Information"
            }
            
            alert.informativeText = self.message
            alert.addButton(withTitle: "OK")
        
            alert.runModal()
        }
    }
}

class BorgWrapper {
    static let binPath = Bundle.main.path(forAuxiliaryExecutable: "borg")!
    
    let repoPath: String
    let passphrase: String
    
    init(repoPath path: String, passphrase: String) {
        self.repoPath = path
        self.passphrase = passphrase
    }
    
    init?(preferences: _AppPreferences) {
        guard let path = preferences.main.repositoryPath,
            let passphrase = preferences.main.passphrase else {
            return nil
        }
        
        self.repoPath = path
        self.passphrase = passphrase
    }
    
    private func run(_ arguments: [String], env: [String: String]) -> BufferedStringSubprocess {
        return BufferedStringSubprocess(BorgWrapper.binPath, arguments: arguments, environment: env)
    }
    
    func initialize(encryption: RepoEncryption = .repokeyBlake2) -> BufferedStringSubprocess {
        let env = [
            "BORG_PASSPHRASE": passphrase,
            "BORG_REPO": repoPath
        ]
        
        let process = run([
            "init", "--log-json",
            "-e", encryption.rawValue,
            repoPath
        ], env: env)
        
        process.onLogOutput = { line in
            guard let json = JSONSerialization.jsonDict(with: line.data(using: .utf8)!) else {
                return
            }
            
            if let type = json["type"] as? String {
                switch type {
                case "question_prompt":
                    DispatchQueue.main.async {
                        process.write(string: questionPrompt(message: json["message"] as? String ?? ""))
                    }
                case "log_message":
                    BorgLogMessage(json: json).showAlert()
                default:
                    break
                }
            }
        }
        
        process.launch()
        return process
    }
    
    func create(archive: String, paths: [String], compression: ArchiveCompression = .lz4) -> BufferedStringSubprocess {
        let env = [
            "BORG_PASSPHRASE": passphrase,
            "BORG_REPO": repoPath
        ]
        
        let process = run([
            "create", "--json", "--log-json", "--progress",
            "-C", compression.rawValue,
            "::\(archive)"] + paths, env: env)
        
        process.onLogOutput = {
            print($0)
        }
        
        process.onLogProgress = {
            print("PROGRESS: \($0)")
        }
        
        return process
    }
    
    func extract(archive: String, paths: [String], outputDirectory: String) -> BufferedStringSubprocess {
        let args = ["extract", "-p", "--log-json", "::\(archive)"] + paths
        
        let process = run(args, env: [
            "BORG_PASSPHRASE": passphrase,
            "BORG_REPO": repoPath
        ])
        
        process.currentDirectoryPath = outputDirectory
        
        process.onLogOutput = {
            print($0)
        }
        
        process.onLogProgress = {
            print("PROGRESS: \($0)")
        }
        
        return process
    }
    
    func info(archive: String? = nil, all: Bool = false) -> BufferedStringSubprocess {
        var args = ["info", "--json", "--log-json"]
        
        if let archive = archive {
            args.append("::\(archive)")
        } else {
            args.append("--last")
            
            if all {
                args.append("9999999")
            } else {
                args.append("1")
            }
        }
        
        let process = run(args, env: [
            "BORG_PASSPHRASE": passphrase,
            "BORG_REPO": repoPath
        ])
        
        process.onLogOutput = {
            print($0)
        }
        
        process.onLogProgress = {
            print("PROGRESS: \($0)")
        }
        
        return process
    }
    
    func list(archive: String? = nil) -> BufferedStringSubprocess {
        var args = ["list", "--json", "--log-json"]
        
        if let archive = archive {
            args.append("::\(archive)")
        }
        
        let process = run(args, env: [
            "BORG_PASSPHRASE": passphrase,
            "BORG_REPO": repoPath
        ])
        
        return process
    }
}

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
