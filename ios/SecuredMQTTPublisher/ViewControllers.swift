//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

extension UIViewController {
    static var settings: SettingsViewController {
        .init(settings: Core.shared.dataStore.settings,
              settingsDidChangeHandler: { Core.shared.dataStore.settings = $0 })
    }
}
