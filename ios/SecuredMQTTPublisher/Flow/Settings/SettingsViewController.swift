//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class SettingsViewController: UIViewController {
    enum Action { case ok, cancel }
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Text>.SingleCellType<TextViewCell>
    
    private enum Layout {
        static let collectionViewContentInsetBottom: CGFloat = 60
    }
    
    private enum Section: CaseIterable {
        case homeTitle
        case mqttEndpoint
        case clientID
        case certificate
        case privateKey
        case rootCA
        case timestampKey
        
        var title: String {
            switch self {
            case .homeTitle: return "Home Title:"
            case .mqttEndpoint: return "MQTT Endpoint:"
            case .clientID: return "Client ID:"
            case .certificate: return "Certificate:"
            case .privateKey: return "Private Key:"
            case .rootCA: return "Root CA:"
            case .timestampKey: return "Timestamp Key:"
            }
        }
        
        var textViewHeight: CGFloat {
            switch self {
            case .homeTitle,
                 .timestampKey: return 40
            case .mqttEndpoint,
                 .clientID: return 60
            case .certificate,
                 .privateKey,
                 .rootCA: return 300
            }
        }
        
        var isTextViewOneline: Bool {
            switch self {
            case .homeTitle,
                 .mqttEndpoint,
                 .clientID,
                 .timestampKey: return true
            case .certificate,
                 .privateKey,
                 .rootCA: return false
            }
        }
    }
    
    private struct Text: Hashable {
        let id = UUID()
        var value: String
    }
    
    private enum ElementKind: String {
        case textViewTitleView
        case biometricAuthSwitch
        case hideUnusedButtonSwitch
    }
    
    private let actionHandler: (SettingsViewController, Action) -> Void
    
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
            let layoutSection = self.makeLayoutSection(textViewHeight: section.textViewHeight)
            let biometricAuthSwitch = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .absolute(52)),
                elementKind: ElementKind.biometricAuthSwitch.rawValue,
                alignment: .bottom,
                absoluteOffset: .init(x: 0, y: 5))
            let hideUnusedButtonSwitch = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .absolute(52)),
                elementKind: ElementKind.hideUnusedButtonSwitch.rawValue,
                alignment: .bottom,
                absoluteOffset: .init(x: 0, y: 57))
            if sectionIndex == Section.allCases.indices.last {
                layoutSection.boundarySupplementaryItems.append(contentsOf: [biometricAuthSwitch,
                                                                             hideUnusedButtonSwitch])
            }
            return layoutSection
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
                case .homeTitle: text = self.editingSettings.homeTitle
                case .mqttEndpoint: text = self.editingSettings.endpoint
                case .clientID: text = self.editingSettings.clientID
                case .certificate: text = self.editingSettings.certificate
                case .privateKey: text = self.editingSettings.privateKey
                case .rootCA: text = self.editingSettings.rootCA ?? ""
                case .timestampKey: text = self.editingSettings.timestampKey ?? ""
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
        let biometricAuthSwitchRegistration = UICollectionView.SupplementaryRegistration<LabelSwitchView>(
            elementKind: ElementKind.biometricAuthSwitch.rawValue) { [weak self] biometricAuthSwitch, _, _ in
            guard let self = self else { return }
            biometricAuthSwitch.display(title: "Touch ID/Face ID")
            biometricAuthSwitch.display(isSwitchOn: self.editingSettings.isBiometricAuthEnabled)
            biometricAuthSwitch.$isOn
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self = self else { return }
                    self.editingSettings.isBiometricAuthEnabled = $0
                }
                .store(in: &self.bag)
        }
        let hideUnusedButtonSwitchRegistration = UICollectionView.SupplementaryRegistration<LabelSwitchView>(
            elementKind: ElementKind.hideUnusedButtonSwitch.rawValue) { [weak self] hideUnusedButtonSwitch, _, _ in
            guard let self = self else { return }
            hideUnusedButtonSwitch.display(title: "Hide Unused Buttons")
            hideUnusedButtonSwitch.display(isSwitchOn: self.editingSettings.isUnusedButtonHidden)
            hideUnusedButtonSwitch.$isOn
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self = self else { return }
                    self.editingSettings.isUnusedButtonHidden = $0
                }
                .store(in: &self.bag)
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            guard let kind = ElementKind(rawValue: kind) else { return nil }
            switch kind {
            case .textViewTitleView:
                return collectionView.dequeueConfiguredReusableSupplementary(using: textViewTitleViewRegistration,
                                                                             for: indexPath)
            case .biometricAuthSwitch:
                return collectionView.dequeueConfiguredReusableSupplementary(using: biometricAuthSwitchRegistration,
                                                                             for: indexPath)
            case .hideUnusedButtonSwitch:
                return collectionView.dequeueConfiguredReusableSupplementary(using: hideUnusedButtonSwitchRegistration,
                                                                             for: indexPath)
            }
        }
        return dataSource
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Settings"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    private lazy var okCancelButtonView: OkCancelButtonsView = {
        let okCancelButtonsView = OkCancelButtonsView()
        okCancelButtonsView.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case .ok:
                    self.settings = self.editingSettings
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var editingSettings: Settings
    
    private var settings: Settings {
        didSet {
            guard oldValue != settings else { return }
            settingsDidChangeHandler(settings)
        }
    }
    private let settingsDidChangeHandler: (Settings) -> Void
    
    private var bag = Set<AnyCancellable>()
    
    init(settings: Settings,
         settingsDidChangeHandler: @escaping (Settings) -> Void,
         actionHandler: @escaping (SettingsViewController, Action) -> Void) {
        self.settings = settings
        self.settingsDidChangeHandler = settingsDidChangeHandler
        self.actionHandler = actionHandler
        self.editingSettings = settings
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
        displaySettings()
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
            collectionView
                .top(to: titleLabel.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            okCancelButtonView
                .top(to: collectionView.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .bottom(to: container.bottom)
                .height(to: 46)
        )
    }
    
    private func displaySettings() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Text>()
        Section.allCases.forEach {
            snapshot.appendSections([$0])
            switch $0 {
            case .homeTitle: snapshot.appendItems([.init(value: editingSettings.homeTitle)])
            case .mqttEndpoint: snapshot.appendItems([.init(value: editingSettings.endpoint)])
            case .clientID: snapshot.appendItems([.init(value: editingSettings.clientID)])
            case .certificate: snapshot.appendItems([.init(value: editingSettings.certificate)])
            case .privateKey: snapshot.appendItems([.init(value: editingSettings.privateKey)])
            case .rootCA: snapshot.appendItems([.init(value: editingSettings.rootCA ?? "")])
            case .timestampKey: snapshot.appendItems([.init(value: editingSettings.timestampKey ?? "")])
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

extension SettingsViewController: UITextViewDelegate {
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
        case .homeTitle: editingSettings.homeTitle = newText
        case .mqttEndpoint: editingSettings.endpoint = newText
        case .clientID: editingSettings.clientID = newText
        case .certificate: editingSettings.certificate = newText
        case .privateKey: editingSettings.privateKey = newText
        case .rootCA: editingSettings.rootCA = newText.isEmpty ? nil : newText
        case .timestampKey: editingSettings.timestampKey = newText.isEmpty ? nil : newText
        }
        
        return true
    }
}
