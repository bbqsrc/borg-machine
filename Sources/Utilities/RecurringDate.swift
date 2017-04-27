//
//  RecurringDate.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 22/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation
import Mapper
import Wrap

fileprivate let weekdayFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "EEEE"
    return df
}()

enum Weekday: Int, WrappableEnum, Comparable, Equatable, CustomStringConvertible {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    
    var description: String {
        return weekdayFormatter.shortWeekdaySymbols[self.rawValue - 1]
    }
    
    public static func ==(lhs: Weekday, rhs: Weekday) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func <(lhs: Weekday, rhs: Weekday) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    public static func <=(lhs: Weekday, rhs: Weekday) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
    public static func >=(lhs: Weekday, rhs: Weekday) -> Bool {
        return lhs.rawValue >= rhs.rawValue
    }
    public static func >(lhs: Weekday, rhs: Weekday) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
}

enum Frequency: String {
    case secondly
    case minutely
    case hourly
    case daily
    case weekly
    case monthly
    case yearly
    
    var shortCode: String {
        let ch = String(self.rawValue.characters.first!)
        
        switch self {
        case .secondly, .minutely, .hourly:
            return ch
        default:
            return ch.uppercased()
        }
    }
}

struct RecurrenceRule: Mappable, Equatable, CustomStringConvertible {
    let weekStart: Weekday
    let interval: UInt
    let count: UInt?
    let until: Date?
    let frequency: Frequency
    let byDay: Set<Weekday>
    
    static func ==(lhs: RecurrenceRule, rhs: RecurrenceRule) -> Bool {
        return lhs.weekStart == rhs.weekStart &&
            lhs.interval == rhs.interval &&
            lhs.count == rhs.count &&
            lhs.until == rhs.until &&
            lhs.frequency == rhs.frequency &&
            lhs.byDay == rhs.byDay
    }
    
    var description: String {
        let unit: String
        
        switch frequency {
        case .daily:
            unit = "day"
        case .hourly:
            unit = "hour"
        case .minutely:
            unit = "minute"
        case .monthly:
            unit = "month"
        case .weekly:
            unit = "week"
        case .secondly:
            unit = "second"
        case .yearly:
            unit = "year"
        }
        
        
        let freqStr = interval > 1 ? "\(interval) \(unit)s" : frequency.rawValue.capitalized
        var out = "\(freqStr)"
        
        let days = Array(byDay)
        
        if days.isNotEmpty {
            out += " - "
            out += days.sorted().map({ $0.description }).joined(separator: ", ")
        }
        
        return out
    }
    
    init(count: UInt, frequency: Frequency, interval: UInt = 1, byDay: [Weekday] = [], weekStart: Weekday = .monday) {
        self.count = count
        self.until = nil
        self.interval = interval
        self.frequency = frequency
        self.byDay = Set(byDay)
        self.weekStart = weekStart
    }
    
    init(until: Date, frequency: Frequency, interval: UInt = 1, byDay: [Weekday] = [], weekStart: Weekday = .monday) {
        self.count = nil
        self.until = until
        self.interval = interval
        self.frequency = frequency
        self.byDay = Set(byDay)
        self.weekStart = weekStart
    }
    
    init(frequency: Frequency, interval: UInt = 1, byDay: [Weekday] = [], weekStart: Weekday = .monday) {
        self.count = nil
        self.until = nil
        self.interval = interval
        self.frequency = frequency
        self.byDay = Set(byDay)
        self.weekStart = weekStart
    }
    
    init(map: Mapper) throws {
        let count: UInt? = map.optionalFrom("count")
        let until: Date? = map.optionalFrom("until")
        
        if count != nil && until != nil {
            throw MapperError.customError(field: nil, message: "Fields `count` or `until` cannot both be non-null")
        }
        
        self.count = count
        self.until = until
        interval = map.optionalFrom("interval") ?? 1
        
        try weekStart = map.from("weekStart")
        try frequency = map.from("frequency")
        
        if let byDayArray: [Int] = map.optionalFrom("byDay") {
            let dayMap = byDayArray.flatMap(Weekday.init(rawValue:))
            byDay = Set(dayMap)
        } else {
            byDay = Set()
        }
    }
}

class RecurringDateIterator: IteratorProtocol {
    private let startDate: Date
    private var curDate: Date
    private let rule: RecurrenceRule
    
    private let calendar = Calendar(identifier: .gregorian)
    private var count: UInt?
    
    fileprivate init(with date: Date, rule: RecurrenceRule) {
        self.startDate = date
        self.curDate = startDate
        self.rule = rule
        self.count = rule.count
    }
    
    private func minutely() -> Date? {
        var dateComponents = DateComponents()
        
        dateComponents.minute = 1
        curDate = calendar.date(byAdding: dateComponents, to: curDate)!
        
        return curDate
    }
    
    private func daily() -> Date? {
        var dateComponents = DateComponents()
        
        dateComponents.day = 1
        curDate = calendar.date(byAdding: dateComponents, to: curDate)!
        
        if rule.byDay.isEmpty {
            return curDate
        }
        
        var weekday = Weekday(rawValue: calendar.component(.weekday, from: curDate))!
        
        while !rule.byDay.contains(weekday) {
            curDate = calendar.date(byAdding: dateComponents, to: curDate)!
            weekday = Weekday(rawValue: calendar.component(.weekday, from: curDate))!
        }
        
        return curDate
    }
    
    public func next() -> Date? {
        if let c = count, c == 0 {
            return nil
        }
        
        defer {
            if let c = count, c > 0 {
                count! -= 1
            }
        }
        
        let out: Date?
        
        switch rule.frequency {
        case .daily:
            out = daily()
        case .minutely:
            out = minutely()
        default:
            out = nil
        }
        
        if let until = rule.until, let out = out, until.compare(out) == .orderedAscending {
            return nil
        }
        
        return out
    }
}

class RecurringDateSequence: Sequence {
    private let date: Date
    private let rule: RecurrenceRule
    
    func makeIterator() -> RecurringDateIterator {
        return RecurringDateIterator(with: date, rule: rule)
    }
    
    fileprivate init(with date: Date, rule: RecurrenceRule) {
        self.date = date
        self.rule = rule
    }
    
    var first: Date? {
        return makeIterator().next()
    }
}

extension Date {
    func recurring(by rule: RecurrenceRule) -> RecurringDateSequence {
        return RecurringDateSequence(with: self, rule: rule)
    }
}

let rule = RecurrenceRule(count: 10, frequency: .daily, byDay: [Weekday.monday])
let x = Date().recurring(by: rule)
