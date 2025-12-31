//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class ActionEditCoordinator: Coordinator {
    private let presenter: UIViewController
    private let actionIndex: Int
    private let didFinishHandler: (ActionEditCoordinator) -> Void
    
    init(presenter: UIViewController,
         actionIndex: Int,
         didFinishHandler: @escaping (ActionEditCoordinator) -> Void) {
        self.presenter = presenter
        self.actionIndex = actionIndex
        self.didFinishHandler = didFinishHandler
    }
    
    func start() {
        guard let action = Core.shared.dataStore.settings.actions[safe: actionIndex] else { return }
        let actionEditViewController =
            ActionEditViewController(action: action,
                                     actionIndex: actionIndex,
                                     actionDidChangeHandler: { [weak self] in
                                        guard let self = self else { return }
                                        Core.shared.dataStore.settings.actions[safe: self.actionIndex] = $0
                                     },
                                     actionHandler: { [weak self] actionEditViewController, _ in
                                        guard let self = self else { return }
                                        actionEditViewController.dismiss(animated: true)
                                        self.didFinishHandler(self)
                                     })

        presenter.present(actionEditViewController, in: .fullScreen, animated: true)
    }
}
