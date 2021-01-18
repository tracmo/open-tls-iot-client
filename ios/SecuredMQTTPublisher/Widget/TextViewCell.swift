//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class TextViewCell: UICollectionViewCell {
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.autocorrectionType = .no
        textView.font = .systemFont(ofSize: 24)
        textView.layer.borderWidth = 2
        textView.layer.borderColor = UIColor.accent.cgColor
        return textView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayouts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayouts()
    }
    
    private func setupLayouts() {
        backgroundColor = .clear
        
        addSubviews(textView
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
}
