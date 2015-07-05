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

@objc public class XWebApp {
    public let bundle: NSBundle
    public init(bundle: NSBundle) {
        self.bundle = bundle
    }

    private(set) public lazy var inventory: XWAPluginInventory = {
        let inventory = XWAPluginInventory()
        if let pluginPath = self.bundle.infoDictionary?["Plugin"] as? String {
            let pluginPath = self.bundle.bundlePath.stringByAppendingPathComponent(pluginPath)
            if let bundle = NSBundle(path: pluginPath) {
                inventory.scanInBundle(bundle)
            } else {
                println("ERROR: Open plugin '\(pluginPath)' failed")
            }
        }
        /* Scan a directory
        let pluginDir = self.bundle.bundlePath.stringByAppendingPathComponent(
            self.bundle.infoDictionary?["PluginDirectory"] as? String ?? "Plugins")
        if let subdirs = NSFileManager.defaultManager().contentsOfDirectoryAtPath(pluginDir, error: nil) {
            for subdir in subdirs {
                let name = subdir as! String
                if name.pathExtension == "framework" || name.pathExtension == "plugin" {
                    let bundlePath = pluginDir.stringByAppendingPathComponent(name)
                    if let bundle = NSBundle(path: bundlePath) {
                        inventory.scanInBundle(bundle)
                    } else {
                        println("ERROR: Open plugin bundle '\(bundlePath)' failed")
                    }
                }
            }
        }*/
        return inventory
    }()

    private(set) public lazy var binding: XWAPluginBinding? = {
        if let config = self.bundle.infoDictionary?["Bindings"] as? [String: AnyObject] {
            let binding = XWAPluginBinding(inventory: self.inventory)
            for (namespace, spec) in config {
                binding.addBinding(spec, forNamespace: namespace)
            }
            return binding
        }
        return nil
    }()

    private(set) public lazy var configuration: WKWebViewConfiguration = {
        let webViewConfig = WKWebViewConfiguration()
        if let config = self.bundle.infoDictionary?["WebViewConfiguration"] as? NSDictionary {
            if let val = config["SuppressesIncrementalRendering"] as? Bool {
                webViewConfig.suppressesIncrementalRendering = val
            }
            if let val = config["AllowsInlineMediaPlayback"] as? Bool {
                webViewConfig.allowsInlineMediaPlayback = val
            }
            if let val = config["MediaPlaybackAllowsAirPlay"] as? Bool {
                webViewConfig.mediaPlaybackAllowsAirPlay = val
            }
            if let val = config["MediaPlaybackRequiresUserAction"] as? Bool {
                webViewConfig.mediaPlaybackRequiresUserAction = val
            }
            if let val = config["SelectionGranularity"] as? String where val == "Character" {
                webViewConfig.selectionGranularity = WKSelectionGranularity.Character
            }
        }
        return webViewConfig
    }()

    public var mainHTML: String {
        return bundle.infoDictionary?["MainHTML"] as? String ?? ""
    }

    //var userScripts: [String]
    //var allowsBackForwardNavigationGestures: Bool
    // minimumFontSize: CGFloat ???

    /*  func configForPlugin(id: String) -> AnyObject? {
        return bundle.infoDictionary?[id]
    }*/
    //var overlay: NSBundle
}
