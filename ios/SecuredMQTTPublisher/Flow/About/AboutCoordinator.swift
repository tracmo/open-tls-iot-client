//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AboutCoordinator: Cooridinator {
    private let presenter: UIViewController
    private let didFinishHandler: (AboutCoordinator) -> Void
    
    init(presenter: UIViewController,
         didFinishHandler: @escaping (AboutCoordinator) -> Void) {
        self.presenter = presenter
        self.didFinishHandler = didFinishHandler
    }
    
    func start() {
        let aboutViewController = AboutViewController(didDisappearHandler: { [weak self] _ in
            guard let self = self else { return }
            self.didFinishHandler(self)
        })
        presenter.present(aboutViewController, in: .pageSheet, animated: true)
    }
}
