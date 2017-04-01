//
//  AppPreferences.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

struct MainPreferences {
    fileprivate var json: [String: Any]
    
    var repositoryPath: String? {
        get { return json["repositoryPath"] as? String }
        set { json["repositoryPath"] = newValue }
    }
    
    var repositoryType: String? {
        get { return json["repositoryType"] as? String }
        set { json["repositoryType"] = newValue }
    }
    
    fileprivate init(json: [String: Any]) {
        self.json = json
    }
}

fileprivate let prefsPath: URL =
    FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("BorgMachine")

fileprivate let mainPreferencesURL: URL =
    prefsPath.appendingPathComponent("preferences.json")

fileprivate func createPrefsPath() {
    try! FileManager.default.createDirectory(
        at: prefsPath,
        withIntermediateDirectories: true,
        attributes: nil
    )
}

class _AppPreferences {
    var main: MainPreferences
    
    init() {
        createPrefsPath()
        
        let data = try? Data(contentsOf: mainPreferencesURL)
        
        if let data = data, let json = JSONSerialization.jsonDict(with: data) {
            main = MainPreferences(json: json)
        } else {
            main = MainPreferences(json: [:])
        }
    }
    
    func save() {
        let data = try? JSONSerialization.data(withJSONObject: main.json, options: [])
        
        if let data = data {
            try? data.write(to: mainPreferencesURL)
        }
    }
}

let AppPreferences = _AppPreferences()
