//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class PencilBadge: UICollectionReusableView {
    private lazy var pencilImageView = UIImageView(image: UIImage(systemName: "pencil.circle",
                                                                  withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 72)))?
                                                    .withTintColor(.accent, renderingMode: .alwaysOriginal))
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondary
        isUserInteractionEnabled = false
        setupLayouts()
    }
    
    private func setupLayouts() {
        addSubviews(pencilImageView
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
}
