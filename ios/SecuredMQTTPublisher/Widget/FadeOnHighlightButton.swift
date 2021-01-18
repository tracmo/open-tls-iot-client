//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

class FadeOnHighlightButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            alpha = isHighlighted ? 0.8 : 1
        }
    }
}
