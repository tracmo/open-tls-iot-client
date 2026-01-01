//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AboutViewController: UIViewController {
    private let okHandler: (AboutViewController) -> Void
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = .black
        textView.isEditable = false
        textView.attributedText = .about
        return textView
    }()
    
    private lazy var okButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setTitleColor(.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 21, weight: .semibold)
        button.setTitle("OK", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                guard let self = self else { return }
                self.okHandler(self)
            },
            for: .touchUpInside
        )
        return button
    }()
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    init(okHandler: @escaping (AboutViewController) -> Void) {
        self.okHandler = okHandler
        super.init(nibName: nil, bundle: nil)
        setupLayouts()
    }
    
    private func setupLayouts() {
        view.backgroundColor = .background
        
        let container = UIView()
        container.backgroundColor = .clear
        
        view.addSubviews(container
                            .top(to: view.safeAreaLayoutGuide.top, 16)
                            .leading(to: view.safeAreaLayoutGuide.leading, 20)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                            .bottom(to: view.safeAreaLayoutGuide.bottom, -16))
        
        container.addSubviews(textView
                                .top(to: container.top)
                                .leading(to: container.leading)
                                .trailing(to: container.trailing),
                              okButton
                                .top(to: textView.bottom, 20)
                                .leading(to: container.leading)
                                .trailing(to: container.trailing)
                                .bottom(to: container.bottom)
                                .height(to: 46))
    }
}

extension String {
    fileprivate func paragraphTitle() -> NSAttributedString {
        self.attributed(color: .accent,
                        font: .systemFont(ofSize: 20, weight: .bold))
    }
    
    fileprivate func paragraphContent(bold: Bool = false) -> NSAttributedString {
        self.attributed(color: .black,
                        font: .systemFont(ofSize: 20, weight: bold ? .bold : .regular))
    }
    
    fileprivate func attributed(color: UIColor,
                                font: UIFont) -> NSAttributedString {
        .init(string: self,
              attributes: [.foregroundColor : color,
                           .font: font])
    }
    
    fileprivate func link() -> NSAttributedString {
        .init(string: self,
              attributes: [.link : URL(string: self)!,
                           .font: UIFont.systemFont(ofSize: 20)])
    }
}

extension NSMutableAttributedString {
    fileprivate func appended(_ attrString: NSAttributedString) -> Self {
        append(attrString)
        return self
    }
}

extension UIImage {
    fileprivate func attributedString() -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = self
        return .init(attachment: attachment)
    }
    
    fileprivate func resized(targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize: CGSize = widthRatio > heightRatio ?
            .init(width: size.width * heightRatio, height: size.height * heightRatio) :
            .init(width: size.width * widthRatio, height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        self.draw(in: rect)
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resized!
    }
}

extension NSAttributedString {
    static fileprivate func paragraphs(_ paragraphs: NSAttributedString...) -> NSAttributedString {
        paragraphs.enumerated().reduce(NSMutableAttributedString()) {
            let result = $0.appended($1.element)
            return ($1.offset != paragraphs.indices.last) ?
                result.appended(.init(string: "\n\n")) :
                result
        }
    }
    
    static fileprivate func paragraph(title: String,
                                      content: String) -> NSAttributedString {
        paragraph(title: title, content: content.paragraphContent())
    }
    
    static fileprivate func paragraph(title: String,
                                      content: NSAttributedString) -> NSAttributedString {
        NSMutableAttributedString()
            .appended(title.paragraphTitle())
            .appended(.init(string: "\n\n"))
            .appended(content)
    }
    
    static fileprivate var about: NSAttributedString {
        .paragraphs(
            #imageLiteral(resourceName: "about_icon").resized(targetSize: .init(width: 64, height: 64)).attributedString(),
            .paragraph(title: "About",
                       content: """
        This open source project is co-sponsored by Care Active Corp. The goal is to build an end-to-end secured MQTTs communication to control an end IoT device. The target is to build a tool supporting the following features:

            - Use only X.509 to authenticate and secure the communication
            - Support CA Root authentication
            - Support Face ID or Touch ID
            - Prevent Middle-Man Attack
            - No need to set a NAT port forward for the end IoT device
        """),
            .paragraph(title: "Privacy",
                       content: NSMutableAttributedString()
                        .appended("The TLS IoT Tool App and all the tools/applications under the Open TLS IoT Client project ".paragraphContent())
                        .appended("do not send any data to anyone but your own configured designated destinations".paragraphContent(bold: true))
                        .appended(".".paragraphContent())),
            .paragraph(title: "Project Information",
                       content: NSMutableAttributedString()
                        .appended("""
        For more information about this project, including the source code, please go to the following link:

        """.paragraphContent())
                        .appended("https://github.com/tracmo/open-tls-iot-client".link())),
            .paragraph(title: "Quick App User Guide",
                       content: "https://github.com/tracmo/open-tls-iot-client/wiki/App-User-Instructions".link()),
            .paragraph(title: "Join Us", content: """
        We welcome your participations. If you are interested in joining this project, please email us via opensource AT careactive.ai
        """),
            .paragraph(title: "License", content: """
        MIT License

        Copyright (c) 2026 Care Active Corp.

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """),
            .paragraph(title: "Acknowledgements",
                       content: NSMutableAttributedString()
                        .appended("""
        This application makes use of the following third party libraries:

        MQTT Client Framework

        """.paragraphContent())
                        .appended("https://github.com/novastone-media/MQTT-Client-Framework".link())
                        .appended("""


        License

        """.paragraphContent())
                        .appended("https://github.com/novastone-media/MQTT-Client-Framework/blob/master/LICENSE".link())
                        .appended("""


        Open SSL for iOS

        """.paragraphContent())
                        .appended("https://github.com/x2on/OpenSSL-for-iPhone".link())
                        .appended("""


        License

        """.paragraphContent())
                        .appended("https://github.com/x2on/OpenSSL-for-iPhone/blob/master/LICENSE".link())
                        .appended("""


        Keychain Swift

        """.paragraphContent())
                        .appended("https://github.com/evgenyneu/keychain-swift".link())
                        .appended("""


        License

        """.paragraphContent())
                        .appended("https://github.com/evgenyneu/keychain-swift/blob/master/LICENSE".link())
                        .appended("""


        CryptoSwift

        """.paragraphContent())
                        .appended("https://github.com/krzyzanowskim/CryptoSwift".link())
                        .appended("""


        License

        """.paragraphContent())
                        .appended("https://github.com/krzyzanowskim/CryptoSwift/blob/master/LICENSE".link())
        ))
    }
}
