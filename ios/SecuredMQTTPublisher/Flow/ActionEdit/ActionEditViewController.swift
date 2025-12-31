//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

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
                                                    nfcSecret: nil)
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
        label.text = "NFC Tag Trigger"
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

    private lazy var writeNFCButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setTitleColor(.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitle("Write NFC Tag", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                self?.writeNFCTagTapped()
            },
            for: .touchUpInside
        )
        return button
    }()

    private lazy var removeNFCButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Remove NFC Trigger", for: .normal)
        button.setTitleColor(.failure, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.addAction(
            .init { [weak self] _ in
                self?.removeNFCTriggerTapped()
            },
            for: .touchUpInside
        )
        return button
    }()

    private lazy var nfcExplanationLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap 'Write NFC Tag' and hold an NFC sticker near your phone. The tag will trigger this action when scanned. Writing a new tag will invalidate any previous tag for this button."
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
        nfcSectionContainer.addSubviews(
            nfcSectionTitle
                .top(to: nfcSectionContainer.top)
                .leading(to: nfcSectionContainer.leading),
            nfcStatusLabel
                .centerY(to: nfcSectionTitle.centerY)
                .trailing(to: nfcSectionContainer.trailing),
            writeNFCButton
                .top(to: nfcSectionTitle.bottom, 12)
                .leading(to: nfcSectionContainer.leading)
                .trailing(to: nfcSectionContainer.trailing)
                .height(to: 40),
            removeNFCButton
                .top(to: writeNFCButton.bottom, 8)
                .centerX(to: nfcSectionContainer.centerX),
            nfcExplanationLabel
                .top(to: removeNFCButton.bottom, 12)
                .leading(to: nfcSectionContainer.leading)
                .trailing(to: nfcSectionContainer.trailing)
                .bottom(to: nfcSectionContainer.bottom)
        )

        updateNFCStatus()
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

    private func updateNFCStatus() {
        let hasNFCSecret = editingAction.nfcSecret != nil && !editingAction.nfcSecret!.isEmpty
        nfcStatusLabel.text = hasNFCSecret ? "Configured" : "Not configured"
        removeNFCButton.isHidden = !hasNFCSecret
    }

    private func writeNFCTagTapped() {
        view.endEditing(true)

        // Generate new secret and URL
        guard let result = NFCTokenManager.generateURLWithNewSecret(for: actionIndex) else {
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
                    // Save the new secret to the action
                    self.editingAction.nfcSecret = newSecret
                    self.action = self.editingAction
                    self.updateNFCStatus()
                    NSLog("NFC: Tag written and secret saved successfully")

                case .failure(let error):
                    // Don't save the secret if write failed
                    NSLog("NFC: Tag write failed: \(error)")
                    self.showAlert(title: "NFC Write Failed", message: error.localizedDescription)
                }

                self.nfcTagWriter = nil
            }
        }
    }

    private func removeNFCTriggerTapped() {
        let alert = UIAlertController(
            title: "Remove NFC Trigger?",
            message: "Previously written NFC tags for this button will no longer work.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(.init(title: "Remove", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.editingAction.nfcSecret = nil
            self.action = self.editingAction
            self.updateNFCStatus()
            NSLog("NFC: Trigger removed for action \(self.actionIndex)")
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
