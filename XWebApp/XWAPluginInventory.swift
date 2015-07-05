/*
 Copyright 2015 XWebView

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

import Foundation

@objc public class XWAPluginInventory {
    private enum Provider {
        case Class(AnyClass?)
        case RealID(String)
    }
    private var plugins = [String: Provider]()

    public init() {
    }

    public func scanInBundle(bundle: NSBundle) {
        if let xwvplugins = bundle.objectForInfoDictionaryKey("XWVPlugins") as? NSDictionary {
            let e = xwvplugins.keyEnumerator()
            while let name = e.nextObject() as? String {
                let id = XWAPluginInventory.identiferForClassName(name, bundle: bundle)
                plugins[id] = .Class(nil)  // lazy load
                if let alias = xwvplugins[name] as? String where !alias.isEmpty {
                    let aid = XWAPluginInventory.identiferForClassName(alias, bundle: bundle)
                    plugins[aid] = .RealID(id)
                }
            }
        }
    }

    class public func identifierForClass(cls: AnyClass) -> String {
        return identiferForClassName(NSStringFromClass(cls), bundle: NSBundle(forClass: cls))
    }
    class private func identiferForClassName(name: String, bundle: NSBundle) -> String {
        var id = name
        if let dot = find(id, ".") {
            id = id.substringFromIndex(dot.successor())
        }
        if bundle != NSBundle.mainBundle() {
            precondition(bundle.bundleIdentifier != nil, "Bundle '\(bundle.bundlePath)' has no identifier")
            id += "@" + ".".join(reverse(split(bundle.bundleIdentifier!) { $0 == "." }))
        }
        return id
    }

    public func registerClass(cls: AnyClass) -> AnyClass! {
        return registerClass(cls, forIdentifier: XWAPluginInventory.identifierForClass(cls))
    }
    public func registerClass(cls: AnyClass!, forIdentifier id: String) -> AnyClass! {
        let old: AnyClass? = classForIdentifier(id)
        plugins[id] = .Class(cls)
        return old
    }
    public func unregisterIdentifier(id: String) {
        plugins.removeValueForKey(id)
    }

    public func classForIdentifier(id: String) -> AnyClass? {
        if let provider = plugins[id] {
            switch provider {
                case .Class(let cls):
                    return cls ?? resolveIdentifier(id)
                case .RealID(let rid):
                    return classForIdentifier(rid)
            }
        }
        return nil
    }

    private func resolveIdentifier(id: String) -> AnyClass? {
        let className: String
        let bundle: NSBundle!
        if let at = find(id, "@") {
            className = id[id.startIndex..<at]
            let domain = id[at.successor()..<id.endIndex]
            let bundleId = ".".join(reverse(split(domain) { $0 == "." }))
            bundle = NSBundle(identifier: bundleId)
            if bundle == nil {
                println("ERROR: Unknown bundle '\(bundleId)'")
                return nil
            } else if !bundle.loaded {
                if !bundle.loadAndReturnError(nil) {
                    println("ERROR: Load bundle '\(bundle.bundlePath)' failed")
                    return nil
                }
            }
        } else {
            className = id
            bundle = NSBundle.mainBundle()
        }

        func classForName(name: String, bundle: NSBundle) -> AnyClass? {
            return TARGET_IPHONE_SIMULATOR == 1 ? NSClassFromString(name) : bundle.classNamed(name)
        }
        var cls: AnyClass? = classForName(className, bundle)
        if cls == nil {
            // Is it a Swift class?
            let className = bundle.executablePath!.lastPathComponent + "." + className
            cls = classForName(className, bundle)
            if cls == nil {
                println("ERROR: Plugin class '\(className)' not found in bundle '\(bundle.bundlePath)'")
            }
        }
        return cls
    }
}

extension XWAPluginInventory {
    public subscript(id: String) -> AnyClass? {
        get {
            return classForIdentifier(id)
        }
        set {
            if newValue != nil {
                registerClass(newValue!, forIdentifier: id)
            } else {
                unregisterIdentifier(id)
            }
        }
    }
}
