//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AboutCoordinator: Coordinator {
    private let presenter: UIViewController
    private let didFinishHandler: (AboutCoordinator) -> Void
    
    init(presenter: UIViewController,
         didFinishHandler: @escaping (AboutCoordinator) -> Void) {
        self.presenter = presenter
        self.didFinishHandler = didFinishHandler
    }
    
    func start() {
        let aboutViewController = AboutViewController(okHandler: { [weak self] in
            guard let self = self else { return }
            $0.dismiss(animated: true)
            self.didFinishHandler(self)
        })
        presenter.present(aboutViewController, in: .fullScreen, animated: true)
    }
}
