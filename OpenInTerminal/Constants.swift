//
//  Config.swift
//  OpenInTerminal
//
//  Created by Jianing Wang on 2019/4/20.
//  Copyright © 2019 Jianing Wang. All rights reserved.
//

import Cocoa
import Foundation
import OpenInTerminalCore
import ServiceManagement

struct Constants {
    
    struct Id {
        static let LauncherApp = "wang.jianing.app.OpenInTerminalHelper"

        /// Bundle identifier of the embedded Finder extension.
        ///
        /// Derived from the host app's own identifier rather than hardcoded:
        /// the extension target is named after the app, so a fork that changes
        /// `PRODUCT_BUNDLE_IDENTIFIER` would otherwise have `checkScripts()`
        /// install the AppleScripts into the *original* developer's
        /// `~/Library/Application Scripts/…` folder, while the extension looks
        /// for them under its own — and silently do nothing when clicked.
        static let FinderExtension: String = {
            let suffix = "OpenInTerminalFinderExtension"
            guard let appId = Bundle.main.bundleIdentifier else {
                return "wang.jianing.app.OpenInTerminal." + suffix
            }
            return appId + "." + suffix
        }()
        static let CustomAppCell = NSUserInterfaceItemIdentifier(rawValue: "customAppCell")
        static let CustomMenuCell = NSUserInterfaceItemIdentifier(rawValue: "customMenuCell")
        static let CustomInputViewController = "CustomInputViewController"
    }
    
    static let none = "None"
    
    struct Key {
        static let defaultTerminalShortcut = "OIT_DefaultTerminalShortcut"
        static let defaultEditorShortcut = "OIT_DefaultEditorShortcut"
        static let copyPathShortcut = "OIT_CopyPathShortcut"
        static let onlyActivateShortcutsInFinder = "OnlyActivateShortcutsInFinder"
    }
    
    static let PreferencesStoryboard = NSStoryboard(name: "Preferences", bundle: nil)
}

enum LaunchAtLoginManager {
    static var isEnabledOrAwaitingApproval: Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            return status == .enabled || status == .requiresApproval
        }

        // The legacy API does not expose registration status. The saved value
        // remains the source of truth on macOS 12 and earlier.
        return DefaultsManager.shared.isLaunchAtLogin
    }

    /// Applies a user-requested login-item state and returns the state that the
    /// preferences UI should display.
    @discardableResult
    static func setEnabled(_ enabled: Bool, openSettingsIfApprovalIsRequired: Bool = true) -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp

            do {
                if enabled {
                    switch service.status {
                    case .enabled, .requiresApproval:
                        break
                    case .notRegistered, .notFound:
                        try service.register()
                    @unknown default:
                        try service.register()
                    }
                } else if service.status != .notRegistered {
                    try service.unregister()
                }
            } catch {
                logw("Unable to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
            }

            if enabled && service.status == .requiresApproval {
                logw("Launch at login requires approval in System Settings")
                if openSettingsIfApprovalIsRequired {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            return service.status == .enabled || service.status == .requiresApproval
        }

        let succeeded = SMLoginItemSetEnabled(Constants.Id.LauncherApp as CFString, enabled)
        if !succeeded {
            logw("Unable to \(enabled ? "enable" : "disable") the legacy launch-at-login helper")
        }
        return succeeded ? enabled : DefaultsManager.shared.isLaunchAtLogin
    }

    /// Upgrades a previously saved launch-at-login preference to SMAppService
    /// without repeatedly registering an already-known service.
    static func reconcileSavedPreference() {
        guard DefaultsManager.shared.isLaunchAtLogin else { return }
        let actualState = setEnabled(true, openSettingsIfApprovalIsRequired: false)
        DefaultsManager.shared.isLaunchAtLogin = actualState
    }
}

extension NSImage {
    
    enum AssetIdentifier: String {
        case StatusBarIcon
    }
    
    convenience init(assetIdentifier: AssetIdentifier) {
        self.init(named: assetIdentifier.rawValue)!
    }
}

extension NSStoryboard {
    
    enum StoryboardIdentifier: String {
        case Preferences
    }
    
    convenience init(storyboardIdentifier: StoryboardIdentifier) {
        self.init(name: storyboardIdentifier.rawValue, bundle: nil)
    }
}
