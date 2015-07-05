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
import WebKit
import XWebView

@objc public class XWAPluginBinding {
    struct Descriptor {
        var pluginID: String
        var argument: AnyObject! = nil
        var channelName: String! = nil
        var mainThread: Bool = false
        var lazyBinding: Bool = false
        init(pluginID: String, argument: AnyObject! = nil) {
            self.pluginID = pluginID
            self.argument = argument
        }
    }

    private var bindings = [String: Descriptor]()
    private let inventory: XWAPluginInventory
    private let pluginQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)

    public init(inventory: XWAPluginInventory) {
        self.inventory = inventory
    }

    public func addBinding(spec: AnyObject, forNamespace namespace: String) {
        if let str = spec as? String where !str.isEmpty {
            // simple spec
            var descriptor = Descriptor(pluginID: str)
            if last(descriptor.pluginID) == "?" {
                descriptor.pluginID = dropLast(descriptor.pluginID)
                descriptor.lazyBinding = true
            }
            if last(descriptor.pluginID) == "!" {
                descriptor.pluginID = dropLast(descriptor.pluginID)
                descriptor.mainThread = true
            }
            bindings[namespace] = descriptor
        } else if let pluginID = spec["Plugin"] as? String {
            // full spec
            var descriptor = Descriptor(pluginID: pluginID, argument: spec["argument"])
            descriptor.channelName = spec["channelName"] as? String
            descriptor.mainThread  = spec["mainThread"]  as? Bool ?? false
            descriptor.lazyBinding = spec["lazyBinding"] as? Bool ?? false
            bindings[namespace] = descriptor
        } else {
            println("ERROR: Unknown binding spec for namespace '\(namespace)'")
        }
    }

    public func prebind(webView: WKWebView) {
        for (namespace, _) in filter(bindings, { !$0.1.lazyBinding }) {
            bind(webView, namespace: namespace)
        }
    }

    func bind(namespace: AnyObject!, argument: AnyObject?, _Promise: XWVScriptObject) {
        let scriptObject = objc_getAssociatedObject(self, unsafeAddressOf(XWVScriptObject)) as? XWVScriptObject
        if let namespace = namespace as? String, let webView = scriptObject?.channel.webView {
            if let obj = bind(webView, namespace: namespace) {
                _Promise.callMethod("resolve", withArguments: [obj], resultHandler: nil)
            } else {
                _Promise.callMethod("reject", withArguments: nil, resultHandler: nil)
            }
        }
    }

    private func bind(webView: WKWebView, namespace: String) -> XWVScriptObject? {
        if let spec = bindings[namespace], let plugin: AnyClass = inventory[spec.pluginID] {
            if let object: AnyObject = instantiateClass(plugin, withArgument: spec.argument) {
                let queue = spec.mainThread ? dispatch_get_main_queue() : pluginQueue
                let channel = XWVChannel(name: spec.channelName, webView: webView, queue: queue)
                return channel.bindPlugin(object, toNamespace: namespace)
            }
            println("ERROR: Failed to create instance of plugin '\(spec.pluginID)'.")
        } else if let spec = bindings[namespace] {
            println("ERROR: Plugin '\(spec.pluginID)' not found.")
        } else {
            println("ERROR: Namespace '\(namespace)' has no binding")
        }
        return nil
    }

    private func instantiateClass(cls: AnyClass, withArgument argument: AnyObject?) -> AnyObject? {
        //XWAPluginFactory.self  // a trick to access static method of protocol
        if class_conformsToProtocol(cls, XWAPluginSingleton.self) {
            return cls.instance()
        } else if class_conformsToProtocol(cls, XWAPluginFactory.self) {
            if argument != nil && cls.createInstanceWithArgument != nil {
                return cls.createInstanceWithArgument!(argument)
            }
            return cls.createInstance()
        }

        var initializer = Selector("initWithArgument:")
        var args: [AnyObject]!
        if class_respondsToSelector(cls, initializer) {
            args = [ argument ?? NSNull() ]
        } else {
            initializer = Selector("init")
            if !class_respondsToSelector(cls, initializer) {
                return cls as AnyObject
            }
        }
        return XWVInvocation.construct(cls, initializer: initializer, arguments: args)
    }
}

extension XWAPluginBinding {
    subscript (namespace: String) -> Descriptor? {
        get {
            return bindings[namespace]
        }
        set {
            bindings[namespace] = newValue
        }
    }
}
