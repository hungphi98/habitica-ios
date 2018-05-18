//
//  AvatarDetailViewDataSource.swift
//  Habitica
//
//  Created by Phillip Thelen on 20.04.18.
//  Copyright © 2018 HabitRPG Inc. All rights reserved.
//

import Foundation
import Habitica_Models

class AvatarDetailViewDataSource: BaseReactiveCollectionViewDataSource<CustomizationProtocol> {
    
    private let customizationRepository = CustomizationRepository()
    private let userRepository = UserRepository()
    
    var customizationGroup: String?
    var customizationType: String
    
    var purchaseSet: ((CustomizationSetProtocol) -> Void)?
    
    private var ownedCustomizations: [OwnedCustomizationProtocol] = []
    private var customizationSets: [CustomizationSetProtocol] = []
    
    private var equippedKey: String?
    
    private var preferences: PreferencesProtocol?
    
    init(type: String, group: String?) {
        self.customizationType = type
        self.customizationGroup = group
        super.init()
        
        disposable.inner.add(customizationRepository.getCustomizations(type: customizationType, group: customizationGroup)
            .combineLatest(with: customizationRepository.getOwnedCustomizations(type: customizationType, group: customizationGroup))
            .on(value: { (customizations, ownedCustomizations) in
                self.ownedCustomizations = ownedCustomizations.value
                self.configureSections(customizations.value)
                self.notify(changes: customizations.changes)
        }).start())
        disposable.inner.add(userRepository.getUser().on(value: { user in
            self.preferences = user.preferences
            
            switch self.customizationType {
            case "shirt":
                self.equippedKey = user.preferences?.shirt
            case "skin":
                self.equippedKey = user.preferences?.skin
            case "hair":
                switch self.customizationGroup {
                case "bangs":
                    self.equippedKey = String(user.preferences?.hair?.bangs ?? 0)
                case "base":
                    self.equippedKey = String(user.preferences?.hair?.base ?? 0)
                case "mustache":
                    self.equippedKey = String(user.preferences?.hair?.mustache ?? 0)
                case "beard":
                    self.equippedKey = String(user.preferences?.hair?.beard ?? 0)
                case "color":
                    self.equippedKey = String(user.preferences?.hair?.color ?? "")
                case "flower":
                    self.equippedKey = String(user.preferences?.hair?.flower ?? 0)
                default:
                    return
                }
            default:
                return
            }
        }).start())
    }
    
    func owns(customization: CustomizationProtocol) -> Bool {
        return ownedCustomizations.contains(where: { (ownedCustomization) -> Bool in
            return ownedCustomization.key == customization.key
        })
    }
    
    private func configureSections(_ customizations: [CustomizationProtocol]) {
        customizationSets.removeAll()
        sections.removeAll()
        sections.append(ItemSection<CustomizationProtocol>())
        for customization in customizations {
            if customization.price > 0 && !customization.isPurchasable {
                if !owns(customization: customization) {
                    continue
                }
            }
            if let set = customization.set {
                if let index = sections.index(where: { (section) -> Bool in
                    return section.key == set.key
                }) {
                    sections[index].items.append(customization)
                } else {
                    customizationSets.append(set)
                    sections.append(ItemSection<CustomizationProtocol>(key: set.key, title: set.text))
                    sections.last?.items.append(customization)
                }
            } else {
                sections[0].items.append(customization)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        
        if let customization = item(at: indexPath), let customizationCell = cell as? CustomizationDetailCell {
            customizationCell.configure(customization: customization, preferences: preferences)
            customizationCell.isCustomizationSelected = customization.key == equippedKey
            customizationCell.currencyView.isHidden = customization.isPurchasable == false && !owns(customization: customization)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if let customization = item(at: indexPath) {
            if customization.isPurchasable == true && !owns(customization: customization) {
                if customization.type == "background" {
                    return CGSize(width: 106, height: 138)
                } else {
                    return CGSize(width: 80, height: 108)
                }
            } else {
                if customization.type == "background" {
                    return CGSize(width: 106, height: 106)
                } else {
                    return CGSize(width: 80, height: 108)
                }
            }
        }
        return CGSize.zero
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        let section = sections[indexPath.section]
        
        if let headerView = view as? CustomizationHeaderView {
            if let set = customizationSets.first(where: { (set) -> Bool in
                return set.key == section.key
            }) {
                headerView.configure(customizationSet: set)
                if set.setItems?.contains(where: { (customization) -> Bool in
                    return !self.owns(customization: customization)
                }) == true && set.setPrice != 0 {
                    headerView.purchaseButton.isHidden = false
                } else {
                    headerView.purchaseButton.isHidden = true
                }
                
                headerView.purchaseButtonTapped = {
                    if let action = self.purchaseSet {
                        action(set)
                    }
                }
            } else {
                headerView.purchaseButton.isHidden = true
            }
            
        }
        
        return view
    }
}