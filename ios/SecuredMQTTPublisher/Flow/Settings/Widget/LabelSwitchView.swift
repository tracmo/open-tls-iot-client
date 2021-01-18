//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class LabelSwitchView: UICollectionReusableView {
    @Published
    private(set) var isOn: Bool = false
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .accent
        label.font = .systemFont(ofSize: 24)
        return label
    }()
    
    private lazy var mySwitch: UISwitch = {
        let mySwitch = UISwitch()
        mySwitch.publisher(for: \.isOn)
            .sink { [weak self] in
                guard let self = self else { return }
                self.isOn = $0
            }
            .store(in: &bag)
        mySwitch.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.isOn = mySwitch.isOn
        },
        for: .valueChanged)
        return mySwitch
    }()
    
    private var bag = Set<AnyCancellable>()
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayouts()
    }
    
    private func setupLayouts() {
        addSubviews(
            titleLabel
                .top(to: top)
                .leading(to: leading)
                .bottom(to: bottom),
            mySwitch
                .leading(to: titleLabel.trailing, 16)
                .trailing(to: trailing, -4)
                .centerY(to: centerY)
        )
    }
    
    func display(title: String?) { titleLabel.text = title }
    func display(isSwitchOn: Bool) { mySwitch.isOn = isSwitchOn }
}
