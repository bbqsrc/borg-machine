//
//  BorgWrapper.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Cocoa
import Mapper

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
                    BorgLogMessage.from(json)?.showAlert()
                default:
                    break
                }
            }
        }
    
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

fileprivate func questionPrompt(message: String) -> String {
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

enum BorgErrorLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"
    case warning = "WARNING"
    case critical = "CRITICAL"
}

fileprivate struct BorgLogMessage: Mappable {
    let name: String
    let msgid: String
    let level: BorgErrorLevel
    let message: String
    
    init(map: Mapper) throws {
        try name = map.from("name")
        try msgid = map.from("msgid")
        level = map.optionalFrom("levelname") ?? .info
        
        let message = map.optionalFrom("message") ?? ""
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func showAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            
            switch self.level {
            case .error, .critical:
                alert.alertStyle = .critical
                alert.messageText = "Borg Machine — Error"
            case .warning:
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

