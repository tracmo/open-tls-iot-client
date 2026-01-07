//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine
import AVFoundation

final class ActionEditViewController: UIViewController {
    enum Action { case ok, cancel, delete }
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Text>.SingleCellType<TextViewCell>
    
    private enum Layout {
        static let collectionViewContentInsetBottom: CGFloat = 60
    }
    
    private enum Section: CaseIterable {
        case title
        case mqttTopic
        case message
        
        var title: String {
            switch self {
            case .title: return "Title:"
            case .mqttTopic: return "MQTT Topic:"
            case .message: return "Message:"
            }
        }
        
        var textViewHeight: CGFloat {
            switch self {
            case .title,
                 .mqttTopic: return 40
            case .message: return 300
            }
        }
        
        var isTextViewOneline: Bool {
            switch self {
            case .title,
                 .mqttTopic: return true
            case .message: return false
            }
        }
    }
    
    private struct Text: Hashable {
        let id = UUID()
        var value: String
    }
    
    private enum ElementKind: String {
        case textViewTitleView
    }
    
    private let actionHandler: (ActionEditViewController, Action) -> Void
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.contentInset = .init(top: 0, left: 0, bottom: Layout.collectionViewContentInsetBottom, right: 0)
        return collectionView
    }()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        .init { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            guard let section = Section.allCases[safe: sectionIndex] else { return nil }
            return self.makeLayoutSection(textViewHeight: section.textViewHeight)
        }
    }()
    
    private func makeLayoutSection(textViewHeight: CGFloat) -> NSCollectionLayoutSection {
        let textView = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                       heightDimension: .absolute(textViewHeight)),
                                                     subitems: [textView])
        let textViewTitleView = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .absolute(33)),
            elementKind: ElementKind.textViewTitleView.rawValue,
            alignment: .top)
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [textViewTitleView]
        section.contentInsets = .init(top: 0, leading: 0, bottom: 10, trailing: 0)
        return section
    }
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(
            collectionView: collectionView,
            cellRegistrationHandler: { [weak self] textViewCell, indexPath, _ in
                guard let self = self else { return }
                guard let section = Section.allCases[safe: indexPath.section] else { return }
                let text: String?
                switch section {
                case .title: text = self.editingAction.title
                case .mqttTopic: text = self.editingAction.topic
                case .message: text = self.editingAction.message
                }
                textViewCell.textView.text = text
                textViewCell.textView.inputAccessoryView = self.doneToolBar
                textViewCell.textView.delegate = self
                textViewCell.textView.tag = indexPath.section
                textViewCell.textView.returnKeyType = section.isTextViewOneline ? .done : .default
            })
        let textViewTitleViewRegistration = UICollectionView.SupplementaryRegistration<TextViewTitleView>(
            elementKind: ElementKind.textViewTitleView.rawValue) { [weak self] textViewTitleView, _, indexPath in
            guard let self = self else { return }
            guard let section = Section.allCases[safe: indexPath.section] else { return }
            textViewTitleView.display(title: section.title)
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            guard let kind = ElementKind(rawValue: kind) else { return nil }
            switch kind {
            case .textViewTitleView:
                return collectionView.dequeueConfiguredReusableSupplementary(using: textViewTitleViewRegistration,
                                                                             for: indexPath)
            }
        }
        return dataSource
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Button Edit"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    private lazy var deleteButton = UIButton(systemImageName: "trash.circle.fill",
                                             size: 40) { [weak self] _ in
        guard let self = self else { return }
        let alert = UIAlertController(title: "Sure to delete button?",
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(.init(title: "CANCEL",
                              style: .default,
                              handler: nil))
        alert.addAction(.init(title: "OK",
                              style: .default,
                              handler: { _ in
                                self.action = .init(title: "",
                                                    topic: "",
                                                    message: "",
                                                    nfcSecrets: [])
                                self.actionHandler(self, .delete)
                              }))
        self.present(alert, animated: true)
    }
    
    private lazy var okCancelButtonView: OkCancelButtonsView = {
        let okCancelButtonsView = OkCancelButtonsView()
        okCancelButtonsView.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case .ok:
                    self.action = self.editingAction
                    self.actionHandler(self, .ok)
                case .cancel:
                    self.actionHandler(self, .cancel)
                }
            }
            .store(in: &self.bag)
        return okCancelButtonsView
    }()
    
    
    private lazy var doneToolBar: UIToolbar = {
        // init with a big enough height to avoid constraint error
        let toolBar = UIToolbar(frame: .init(x: 0, y: 0, width: 0, height: 100))
        toolBar.setItems([.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          .init(barButtonSystemItem: .done, target: self, action: #selector(doneToolBarDoneButtonDidTap(_:)))],
                         animated: false)
        toolBar.sizeToFit()
        return toolBar
    }()

    @objc private func doneToolBarDoneButtonDidTap(_ sender: Any) { view.endEditing(true) }

    // MARK: - NFC UI Components

    private lazy var nfcSectionContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = !NFCTagWriter.isAvailable
        return view
    }()

    private lazy var nfcSectionTitle: UILabel = {
        let label = UILabel()
        label.text = "NFC Tag Triggers"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()

    private lazy var nfcStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        return label
    }()

    private lazy var nfcButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private lazy var writeNFCButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setTitleColor(.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitle("Write New Tag", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                self?.writeNFCTagTapped()
            },
            for: .touchUpInside
        )
        return button
    }()

    private lazy var importQRButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .systemGray5
        button.setTitleColor(.accent, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitle("Import via QR Code", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                self?.importViaQRCodeTapped()
            },
            for: .touchUpInside
        )
        return button
    }()

    private lazy var nfcTagsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private lazy var removeAllNFCButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Remove All NFC Triggers", for: .normal)
        button.setTitleColor(.failure, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.addAction(
            .init { [weak self] _ in
                self?.removeAllNFCTriggersTapped()
            },
            for: .touchUpInside
        )
        return button
    }()

    private lazy var nfcExplanationLabel: UILabel = {
        let label = UILabel()
        label.text = "Configure up to 3 NFC tags per button. Use 'Share' to transfer secrets between your trusted devices via QR code."
        label.textColor = .tertiaryLabel
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 0
        return label
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var editingAction: SecuredMQTTPublisher.Action
    private let actionIndex: Int

    private var action: SecuredMQTTPublisher.Action {
        didSet {
            guard oldValue != action else { return }
            actionDidChangeHandler(action)
        }
    }
    private let actionDidChangeHandler: (SecuredMQTTPublisher.Action) -> Void

    private var bag = Set<AnyCancellable>()
    private var nfcTagWriter: NFCTagWriter?

    init(action: SecuredMQTTPublisher.Action,
         actionIndex: Int,
         actionDidChangeHandler: @escaping (SecuredMQTTPublisher.Action) -> Void,
         actionHandler: @escaping (ActionEditViewController, Action) -> Void) {
        self.action = action
        self.actionIndex = actionIndex
        self.actionDidChangeHandler = actionDidChangeHandler
        self.actionHandler = actionHandler
        self.editingAction = action
        super.init(nibName: nil, bundle: nil)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(handleKeyboardWillHideOrWillShowNotification(_:)),
                                       name: UIResponder.keyboardWillHideNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleKeyboardWillHideOrWillShowNotification(_:)),
                                       name: UIResponder.keyboardWillShowNotification,
                                       object: nil)
        setupLayouts()
        displayAction()
    }
    
    private func setupLayouts() {
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewDidTap(_:))))
        view.backgroundColor = .background

        let container = UIView()
        container.backgroundColor = .clear

        view.addSubviews(container
                            .top(to: view.safeAreaLayoutGuide.top, 32)
                            .leading(to: view.safeAreaLayoutGuide.leading, 20)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                            .bottom(to: view.safeAreaLayoutGuide.bottom, -16))

        container.addSubviews(
            titleLabel
                .top(to: container.top)
                .centerX(to: container.centerX),
            deleteButton
                .centerY(to: titleLabel.centerY)
                .trailing(to: container.trailing)
                .width(to: 40)
                .height(to: 40),
            collectionView
                .top(to: titleLabel.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            nfcSectionContainer
                .top(to: collectionView.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            okCancelButtonView
                .top(to: nfcSectionContainer.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .bottom(to: container.bottom)
                .height(to: 46)
        )

        // Setup NFC section internal layout
        nfcButtonsStack.addArrangedSubview(writeNFCButton)
        nfcButtonsStack.addArrangedSubview(importQRButton)

        nfcSectionContainer.addSubviews(
            nfcSectionTitle
                .top(to: nfcSectionContainer.top)
                .leading(to: nfcSectionContainer.leading),
            nfcStatusLabel
                .centerY(to: nfcSectionTitle.centerY)
                .trailing(to: nfcSectionContainer.trailing),
            nfcButtonsStack
                .top(to: nfcSectionTitle.bottom, 12)
                .leading(to: nfcSectionContainer.leading)
                .trailing(to: nfcSectionContainer.trailing)
                .height(to: 40),
            nfcTagsStack
                .top(to: nfcButtonsStack.bottom, 12)
                .leading(to: nfcSectionContainer.leading)
                .trailing(to: nfcSectionContainer.trailing),
            removeAllNFCButton
                .top(to: nfcTagsStack.bottom, 8)
                .centerX(to: nfcSectionContainer.centerX),
            nfcExplanationLabel
                .top(to: removeAllNFCButton.bottom, 12)
                .leading(to: nfcSectionContainer.leading)
                .trailing(to: nfcSectionContainer.trailing)
                .bottom(to: nfcSectionContainer.bottom)
        )

        updateNFCUI()
    }
    
    private func displayAction() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Text>()
        Section.allCases.forEach {
            snapshot.appendSections([$0])
            switch $0 {
            case .title: snapshot.appendItems([.init(value: editingAction.title)])
            case .mqttTopic: snapshot.appendItems([.init(value: editingAction.topic)])
            case .message: snapshot.appendItems([.init(value: editingAction.message)])
            }
        }
        dataSource.apply(snapshot)
    }
    
    @objc func handleKeyboardWillHideOrWillShowNotification(_ notification: Notification) {
        let bottomInset: CGFloat
        
        switch notification.name {
        case UIResponder.keyboardWillHideNotification: bottomInset = Layout.collectionViewContentInsetBottom
        case UIResponder.keyboardWillShowNotification:
            guard let keyboardFrameInValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            let keyboardEndFrameInScreen = keyboardFrameInValue.cgRectValue
            bottomInset = keyboardEndFrameInScreen.height - view.safeAreaInsets.bottom
        default: return
        }
        
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = insets
    }
    
    @objc private func viewDidTap(_ sender: Any) { view.endEditing(true) }
}

extension ActionEditViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        let textViewFrameInCollectionView = textView.convert(textView.bounds, to: collectionView)
        collectionView.scrollRectToVisible(textViewFrameInCollectionView, animated: true)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let section = Section.allCases[safe: textView.tag] else { return true }
        
        let shouldEndEditing = section.isTextViewOneline && text == "\n"
        if shouldEndEditing {
            textView.endEditing(true)
            return false
        }
        
        let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
        
        switch section {
        case .title: editingAction.title = newText
        case .mqttTopic: editingAction.topic = newText
        case .message: editingAction.message = newText
        }

        return true
    }
}

// MARK: - NFC Handling

extension ActionEditViewController {

    private func updateNFCUI() {
        let count = editingAction.nfcSecrets.count
        let maxCount = SecuredMQTTPublisher.Action.maxNFCSecrets

        // Update status label
        if count == 0 {
            nfcStatusLabel.text = "Not configured"
        } else {
            nfcStatusLabel.text = "\(count) of \(maxCount)"
        }

        // Enable/disable write button based on max limit
        writeNFCButton.isEnabled = count < maxCount
        writeNFCButton.alpha = count < maxCount ? 1.0 : 0.5

        // Show/hide remove all button
        removeAllNFCButton.isHidden = count == 0

        // Rebuild tags list
        rebuildTagsList()
    }

    private func rebuildTagsList() {
        // Remove all existing tag views
        nfcTagsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Add a view for each configured tag
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        for (index, secret) in editingAction.nfcSecrets.enumerated() {
            let tagView = createTagRowView(
                label: secret.label ?? "Tag \(index + 1)",
                date: dateFormatter.string(from: secret.createdAt),
                index: index,
                onDelete: { [weak self] in
                    self?.removeNFCTag(at: index)
                }
            )
            nfcTagsStack.addArrangedSubview(tagView)
        }
    }

    private func createTagRowView(label: String, date: String, index: Int, onDelete: @escaping () -> Void) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGray6
        container.layer.cornerRadius = 8

        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.textColor = .label
        labelLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let editIcon = UIImageView(image: UIImage(systemName: "pencil"))
        editIcon.tintColor = .tertiaryLabel
        editIcon.contentMode = .scaleAspectFit

        let dateLabel = UILabel()
        dateLabel.text = date
        dateLabel.textColor = .secondaryLabel
        dateLabel.font = .systemFont(ofSize: 13)

        let shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "qrcode"), for: .normal)
        shareButton.tintColor = .accent
        shareButton.addAction(.init { [weak self] _ in
            self?.shareTagSecret(at: index)
        }, for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemGray3
        deleteButton.addAction(.init { _ in onDelete() }, for: .touchUpInside)

        // Add tap gesture to edit label
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tagRowTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = index
        container.isUserInteractionEnabled = true

        container.addSubviews(
            labelLabel
                .leading(to: container.leading, 12)
                .centerY(to: container.centerY),
            editIcon
                .leading(to: labelLabel.trailing, 4)
                .centerY(to: container.centerY)
                .width(to: 14)
                .height(to: 14),
            dateLabel
                .leading(to: editIcon.trailing, 8)
                .centerY(to: container.centerY),
            deleteButton
                .trailing(to: container.trailing, -8)
                .centerY(to: container.centerY)
                .width(to: 30)
                .height(to: 30),
            shareButton
                .trailing(to: deleteButton.leading, -8)
                .centerY(to: container.centerY)
                .width(to: 30)
                .height(to: 30)
        )

        container.heightAnchor.constraint(equalToConstant: 44).isActive = true

        return container
    }

    @objc private func tagRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view else { return }
        let index = container.tag
        editTagLabel(at: index)
    }

    private func editTagLabel(at index: Int) {
        guard index >= 0 && index < editingAction.nfcSecrets.count else { return }

        let currentLabel = editingAction.nfcSecrets[index].label ?? ""

        let alert = UIAlertController(
            title: "Edit Tag Label",
            message: "Enter a new label for this NFC tag",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = currentLabel
            textField.placeholder = "Label"
            textField.autocapitalizationType = .words
        }
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let newLabel = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            self.editingAction.nfcSecrets[index].label = newLabel?.isEmpty == true ? nil : newLabel
            self.action = self.editingAction
            self.updateNFCUI()
            NSLog("NFC: Updated label for tag at index \(index) to: \(newLabel ?? "nil")")
        })
        present(alert, animated: true)
    }

    private func writeNFCTagTapped() {
        view.endEditing(true)

        // Check if we've reached the limit
        guard editingAction.nfcSecrets.count < SecuredMQTTPublisher.Action.maxNFCSecrets else {
            showAlert(title: "Limit Reached", message: "You can only configure up to \(SecuredMQTTPublisher.Action.maxNFCSecrets) NFC tags per button.")
            return
        }

        // Prompt for optional label
        let alert = UIAlertController(
            title: "New NFC Tag",
            message: "Enter an optional label for this tag (e.g., 'Kitchen', 'Bedroom')",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Label (optional)"
            textField.autocapitalizationType = .words
        }
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Write Tag", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let label = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            self.writeNewTag(withLabel: label?.isEmpty == true ? nil : label)
        })
        present(alert, animated: true)
    }

    private func writeNewTag(withLabel label: String?) {
        // Generate new secret and URL
        guard let result = NFCTokenManager.generateURLWithNewSecret(for: actionIndex, label: label) else {
            showAlert(title: "Error", message: "Failed to generate NFC URL")
            return
        }

        let newSecret = result.secret
        let urlToWrite = result.url

        NSLog("NFC: Writing URL to tag: \(urlToWrite)")

        // Create the tag writer and write
        nfcTagWriter = NFCTagWriter()
        nfcTagWriter?.writeURL(urlToWrite) { [weak self] writeResult in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch writeResult {
                case .success:
                    // Add the new secret to the action's secrets array
                    self.editingAction.nfcSecrets.append(newSecret)
                    self.action = self.editingAction
                    self.updateNFCUI()
                    NSLog("NFC: Tag written and secret saved successfully")

                case .failure(let error):
                    // Don't save the secret if write failed
                    if case NFCTagWriter.WriterError.userCancelled = error {
                        // User cancelled - no alert needed
                    } else {
                        NSLog("NFC: Tag write failed: \(error)")
                        self.showAlert(title: "NFC Write Failed", message: error.localizedDescription)
                    }
                }

                self.nfcTagWriter = nil
            }
        }
    }

    // MARK: - QR Code Sharing

    private func shareTagSecret(at index: Int) {
        guard index >= 0 && index < editingAction.nfcSecrets.count else { return }

        let secret = editingAction.nfcSecrets[index]
        let actionTitle = editingAction.title.isEmpty ? "Button \(actionIndex + 1)" : editingAction.title

        // Generate QR code
        guard let qrImage = QRCodeGenerator.generateQRCode(for: secret, actionIndex: actionIndex) else {
            showAlert(title: "Error", message: "Failed to generate QR code")
            return
        }

        let secretLabel = secret.label ?? "Tag \(index + 1)"
        let qrViewController = QRCodeDisplayViewController(
            qrCodeImage: qrImage,
            secretLabel: secretLabel,
            actionTitle: actionTitle
        )
        qrViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(qrViewController, animated: true)

        NSLog("QR: Displayed QR code for secret at index \(index)")
    }

    private func importViaQRCodeTapped() {
        view.endEditing(true)

        // Check if we've reached the limit
        guard editingAction.nfcSecrets.count < SecuredMQTTPublisher.Action.maxNFCSecrets else {
            showAlert(title: "Limit Reached", message: "You can only configure up to \(SecuredMQTTPublisher.Action.maxNFCSecrets) NFC tags per button.")
            return
        }

        // Check camera permission
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if granted {
                    self.showQRScanner()
                } else {
                    self.showAlert(
                        title: "Camera Access Required",
                        message: "Please enable camera access in Settings to scan QR codes."
                    )
                }
            }
        }
    }

    private func showQRScanner() {
        let scanner = QRCodeScannerViewController { [weak self] url in
            self?.handleScannedQRCode(url)
        }
        scanner.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(scanner, animated: true)
    }

    private func handleScannedQRCode(_ url: URL) {
        NSLog("QR: Scanned URL: \(url.absoluteString)")

        // Parse the share URL
        guard let parsed = QRCodeGenerator.parseShareURL(url) else {
            showAlert(title: "Invalid QR Code", message: "This QR code is not a valid NFC secret share code.")
            return
        }

        // Check if scanned for correct button
        if parsed.actionIndex != actionIndex {
            showAlert(
                title: "Different Button",
                message: "This secret is for button \(parsed.actionIndex + 1), but you're editing button \(actionIndex + 1). Please scan a QR code for this button."
            )
            return
        }

        // Check if this secret already exists
        if editingAction.nfcSecrets.contains(where: { $0.secret == parsed.secret }) {
            showAlert(title: "Already Added", message: "This secret has already been added to this button.")
            return
        }

        // Prompt for label
        let alert = UIAlertController(
            title: "Import NFC Secret",
            message: "Enter an optional label for this imported secret",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = parsed.label
            textField.placeholder = "Label (optional)"
            textField.autocapitalizationType = .words
        }
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Import", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let label = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            let finalLabel = label?.isEmpty == true ? parsed.label : label

            let newSecret = NFCSecret(secret: parsed.secret, label: finalLabel)
            self.editingAction.nfcSecrets.append(newSecret)
            self.action = self.editingAction
            self.updateNFCUI()
            NSLog("QR: Imported secret with label: \(finalLabel ?? "nil")")
        })
        present(alert, animated: true)
    }

    private func removeNFCTag(at index: Int) {
        guard index >= 0 && index < editingAction.nfcSecrets.count else { return }

        let tagLabel = editingAction.nfcSecrets[index].label ?? "Tag \(index + 1)"

        let alert = UIAlertController(
            title: "Remove '\(tagLabel)'?",
            message: "This NFC tag will no longer trigger this action.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Remove", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.editingAction.nfcSecrets.remove(at: index)
            self.action = self.editingAction
            self.updateNFCUI()
            NSLog("NFC: Removed tag at index \(index)")
        })
        present(alert, animated: true)
    }

    private func removeAllNFCTriggersTapped() {
        let count = editingAction.nfcSecrets.count
        guard count > 0 else { return }

        let alert = UIAlertController(
            title: "Remove All NFC Triggers?",
            message: "All \(count) configured NFC tag(s) will stop working for this button.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Remove All", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.editingAction.nfcSecrets.removeAll()
            self.action = self.editingAction
            self.updateNFCUI()
            NSLog("NFC: All triggers removed for action \(self.actionIndex)")
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
