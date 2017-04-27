//
//  AppPreferences.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import Mapper
import Wrap
import RxSwift

fileprivate let prefsPath: URL =
    FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("BorgMachine")

fileprivate let mainPreferencesURL: URL =
    prefsPath.appendingPathComponent("preferences.json")

fileprivate let dateFormatter: DateFormatter = {
    let it = DateFormatter()
    it.locale = Locale(identifier: "en_US_POSIX")
    it.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return it
}()

fileprivate func createPrefsPath() {
    try! FileManager.default.createDirectory(
        at: prefsPath,
        withIntermediateDirectories: true,
        attributes: nil
    )
}

fileprivate let wrapper = Wrapper(context: nil, dateFormatter: dateFormatter)

class AppPreferencesImpl {
    let main = Variable<MainPreferences>(MainPreferences())
    
    fileprivate init() {
        createPrefsPath()
        
        let data = try? Data(contentsOf: mainPreferencesURL)
        
        if let data = data,
            let json = JSONSerialization.jsonDict(with: data),
            let main = MainPreferences.from(json)
        {
            self.main.value = main
        }
    }
    
    func save() {
        guard let json = try? wrapper.wrap(object: main.value) else {
            print("Save didn't succeed, tears, everywhere.")
            return
        }
        
        let data = try? JSONSerialization.data(withJSONObject: json, options: [])
        
        if let data = data {
            try? data.write(to: mainPreferencesURL)
        }
    }
}

let AppPreferences = AppPreferencesImpl()
