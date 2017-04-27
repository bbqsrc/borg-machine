//
//  Extensions.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import RxSwift
import Mapper

infix operator =>

func =>(lhs: Disposable, rhs: DisposeBag) {
    rhs.insert(lhs)
}

func +=(lhs: DisposeBag, rhs: Disposable) {
    lhs.insert(rhs)
}

extension JSONSerialization {
    static func jsonDict(with data: Data) -> [String: Any]? {
        let anyObj = try? JSONSerialization.jsonObject(with: data, options: [])
        
        if let anyObj = anyObj {
            return anyObj as? [String: Any]
        }
        
        return nil
    }
}

extension NSMenuItem {
    convenience init(title: String, target: AnyObject? = nil, action: Selector? = nil) {
        self.init(title: title, action: action, keyEquivalent: "")
        self.target = target
    }
}

protocol Nibbable {}

extension NSMenu: Nibbable {}

extension Nibbable where Self: NSUserInterfaceItemIdentification {
    static var nibName: String {
        return String(describing: self)
    }
    
    static func loadFromNib(named nibName: String? = nil) -> Self {
        let bundle = Bundle(for: Self.self)
        
        var views = NSArray()
        if let nib = NSNib(nibNamed: nibName ?? Self.nibName, bundle: bundle) {
            nib.instantiate(withOwner: nil, topLevelObjects: &views)
        }
        
        guard let view = views.first(where: { $0 is Self }) as? Self else {
            fatalError("Nib could not be loaded for nibName: \(self.nibName); check that the XIB owner has been set to the given view: \(self)")
        }
        
        return view
    }
}

extension NSSegmentedControl {
    var selectedSegments: [Int] {
        return (0..<self.segmentCount).flatMap({ self.isSelected(forSegment: $0) ? $0 : nil })
    }
}

class ViewController<T: NSView>: NSViewController where T: Nibbable {
    let contentView = T.loadFromNib()
    
    override func loadView() {
        view = contentView
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension Date {
    func iso8601String() -> String {
        let formatter = DateFormatter()
        let locale = Locale(identifier: "en_US_POSIX")
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        return formatter.string(from: self)
    }
}

extension FileManager {
    // http://stackoverflow.com/a/28660040
    // https://gist.github.com/NikolaiRuhe/eeb135d20c84a7097516
    func allocatedDirectorySize(at directoryURL: URL) throws -> Int64 {
        var accumulatedSize = Int64(0)
        
        let prefetchedProperties: [URLResourceKey] = [
            .isRegularFileKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]
        
        var errorDidOccur: Error?
        let errorHandler: (URL, Error) -> Bool = { _, error in
            errorDidOccur = error
            return false
        }
        
        let enumerator = self.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: prefetchedProperties,
            options: [],
            errorHandler: errorHandler)!
        
        for item in enumerator {
            let contentItemURL = item as! URL
            
            if let error = errorDidOccur { throw error }
            
            guard let isRegularFile = try contentItemURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile else {
                preconditionFailure()
            }
            
            guard isRegularFile else {
                continue
            }
            
            let res = try contentItemURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .totalFileSizeKey])
            let size = Int64(res.totalFileSize ?? res.fileSize ?? 0)
            
            accumulatedSize += size
        }
        
        if let error = errorDidOccur { throw error }
        
        return accumulatedSize
    }
    
    func countFilesRecursive(at directoryURL: URL) throws -> Int64 {
        var count = Int64(0)
        
        let prefetchedProperties: [URLResourceKey] = [.isRegularFileKey]
        
        var errorDidOccur: Error?
        let errorHandler: (URL, Error) -> Bool = { _, error in
            errorDidOccur = error
            return false
        }
        
        let enumerator = self.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: prefetchedProperties,
            options: [],
            errorHandler: errorHandler)!
        
        for item in enumerator {
            let contentItemURL = item as! URL
            
            if let error = errorDidOccur { throw error }
            
            guard let isRegularFile = try contentItemURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile else {
                preconditionFailure()
            }
            
            guard isRegularFile else {
                continue
            }
            
            count += 1
        }
        
        if let error = errorDidOccur { throw error }
        
        return count
    }
}

extension NSWindowController {
    static let windowKey = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    
    func show(_ sender: Any) {
        guard let window = window else { return }
        
        WindowWatcher.hold(window)
        
        self.showWindow(sender)
        window.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Mappable {
    static func from(_ JSON: [String: Any?]) -> Self? {
        return self.from(JSON as NSDictionary)
    }
}

class TimerBlockTrampoline: NSObject {
    static let key = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
    
    var block: (Timer) -> Void
    
    init(block: @escaping (Timer) -> Void) {
        self.block = block
    }
    
    @objc func fire(_ sender: Any) {
        block(sender as! Timer)
    }
}

extension Timer {
    public convenience init(fireAt date: Date, interval ti: TimeInterval, repeats rep: Bool, block: @escaping (Timer) -> Void) {
        let trampoline = TimerBlockTrampoline(block: block)
        
        self.init(fireAt: date, interval: ti, target: trampoline, selector: #selector(TimerBlockTrampoline.fire(_:)), userInfo: nil, repeats: rep)
        
        objc_setAssociatedObject(self, TimerBlockTrampoline.key,
                                 trampoline, .OBJC_ASSOCIATION_RETAIN)
    }
}

extension Date: Convertible {
    public static func fromMap(_ value: Any) throws -> Date {
        guard let string = value as? String else {
            throw MapperError.convertibleError(value: value, type: String.self)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        ]
        
        for i in 0..<formats.count {
            dateFormatter.dateFormat = formats[i]
            
            let date = dateFormatter.date(from: string)
            
            if (date != nil) {
                return date!
            }
        }
        
        throw MapperError.convertibleError(value: value, type: String.self)
    }
}
