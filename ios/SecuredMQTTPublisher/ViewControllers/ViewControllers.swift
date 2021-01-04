//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

extension UIViewController {
    static var home: HomeViewController { .init(core: .shared) }
    
    static func actionEdit(index: Int) -> ActionEditViewController? {
        guard let action = Core.shared.dataStore.settings.actions[safe: index] else { return nil }
        return .init(action: action,
                     actionDidChangeHandler: { Core.shared.dataStore.settings.actions[safe: index] = $0 })
    }
    
    static var settings: SettingsViewController {
        .init(settings: Core.shared.dataStore.settings,
              settingsDidChangeHandler: { Core.shared.dataStore.settings = $0 })
    }
}
