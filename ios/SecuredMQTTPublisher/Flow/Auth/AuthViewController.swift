//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine
import LocalAuthentication

final class AuthViewController: UIViewController {
    private let authDidSucceedHandler: (AuthViewController) -> Void
    
    private lazy var titleLabel: UILabel = {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Secured MQTT Publisher"
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .accent
        label.text = appName
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var authButton: UIButton = {
        let systemImageName: String
        switch DeviceOwnerAuthenticator.getBiometryType() {
        case .none: systemImageName = "questionmark.square.dashed"
        case .touchID: systemImageName  = "touchid"
        case .faceID: systemImageName = "faceid"
        @unknown default: systemImageName = "questionmark.square.dashed"
        }
        
        let systemImage =
            UIImage(systemName: systemImageName,
                    withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 64)))?
            .withTintColor(.secondary, renderingMode: .alwaysOriginal)
        
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setImage(systemImage, for: .normal)
        button.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.auth()
        },
        for: .touchUpInside)
        return button
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    private var bag = Set<AnyCancellable>()
    
    private var hasUserCancelledAuthInAActiveSession = false
    
    private var observers = [AnyObject]()
    
    init(authDidSucceedHandler: @escaping (AuthViewController) -> Void) {
        self.authDidSucceedHandler = authDidSucceedHandler
        super.init(nibName: nil, bundle: nil)
        setupLayouts()
        
        let center = NotificationCenter.default
        observers.append(contentsOf: [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                               object: nil,
                               queue: .main) { [weak self] _ in
                guard let self = self else { return }
                guard !self.hasUserCancelledAuthInAActiveSession else { return }
                self.auth()
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification,
                               object: nil,
                               queue: .main) { [weak self] _ in
                guard let self = self else { return }
                self.hasUserCancelledAuthInAActiveSession = false
            }
        ])
    }
    
    private func setupLayouts() {
        view.backgroundColor = .background
        
        let container = UIView()
        container.backgroundColor = .clear
        
        view.addSubviews(container
                            .leading(to: view.safeAreaLayoutGuide.leading, 16)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -16)
                            .centerY(to: view.safeAreaLayoutGuide.centerY))
        
        container.addSubviews(
            titleLabel
                .top(to: container.top)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            authButton
                .top(to: titleLabel.bottom, 40)
                .centerX(to: container.centerX)
                .bottom(to: container.bottom)
                .width(to: 130)
                .height(to: 130)
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func auth(cancelledHandler: (() -> Void)? = nil) {
        DeviceOwnerAuthenticator.auth()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] in
                guard let self = self else { return }
                if let _ = $0.getError() {
                    self.hasUserCancelledAuthInAActiveSession = true
                } else {
                    self.authDidSucceedHandler(self)
                }
            }, receiveValue: { _ in })
            .store(in: &self.bag)
    }
    
    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
    }
}
