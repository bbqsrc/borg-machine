//
//  Extensions.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

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
    convenience init(title: String, action: Selector? = nil) {
        self.init(title: title, action: action, keyEquivalent: "")
    }
}

protocol Nibbable {}

extension Nibbable where Self: NSView {
    static var nibName: String {
        return String(describing: self)
    }
    
    static func loadFromNib() -> Self {
        let bundle = Bundle(for: Self.self)
        
        var views = NSArray()
        bundle.loadNibNamed(nibName, owner: Self.self, topLevelObjects: &views)
        
        guard let view = views.first(where: { $0 is Self }) as? Self else {
            fatalError("Nib could not be loaded for nibName: \(self.nibName); check that the XIB owner has been set to the given view: \(self)")
        }
        
        return view
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
