//
//  ScheduleRule.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 25/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper

struct ScheduleRule: Mappable, Equatable {
    let hour: UInt
    let minute: UInt
    let rule: RecurrenceRule
    
    init(map: Mapper) throws {
        try hour = map.from("hour")
        try minute = map.from("minute")
        try rule = map.from("rule")
    }
    
    static func ==(lhs: ScheduleRule, rhs: ScheduleRule) -> Bool {
        return lhs.hour == rhs.hour &&
            lhs.minute == rhs.minute &&
            lhs.rule == rhs.rule
    }
    
    init?(hour: UInt, minute: UInt, rule: RecurrenceRule) {
        if hour > 23 || minute > 59 {
            return nil
        }
        
        self.hour = hour
        self.minute = minute
        self.rule = rule
    }
    
    func nextDate() -> Date? {
        var c = DateComponents()
        c.day = -7
        
        let cal = Calendar.current
        
        let start = cal.date(byAdding: c, to: Date())!
        let now = Date()
        
        for d in start.recurring(by: rule) {
            let nd = cal.date(bySettingHour: Int(hour), minute: Int(minute), second: 0, of: d)!
            
            if now.compare(nd) == .orderedAscending {
                return nd
            }
        }
        
        return nil
    }
    
    var timeString: String {
        let date = Calendar.current.date(
            bySettingHour: Int(hour), minute: Int(minute),
            second: 0, of: Date(timeIntervalSince1970: 0))!
        
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}
