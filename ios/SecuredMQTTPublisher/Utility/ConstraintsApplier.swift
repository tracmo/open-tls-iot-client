//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

extension UIView {
    final class ConstraintsApplier {
        let target: UIView
        var constraints: [NSLayoutConstraint] = []
        
        init(_ target: UIView) { self.target = target }
        
        func apply() {
            target.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(constraints)
        }
        
        func top(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.top, to: anchor, constant)
        }
        
        func bottom(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.bottom, to: anchor, constant)
        }
        
        func leading(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.leading, to: anchor, constant)
        }
        
        func trailing(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.trailing, to: anchor, constant)
        }
        
        func centerX(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.centerX, to: anchor, constant)
        }
        
        func centerY(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> Self {
            append(target.centerY, to: anchor, constant)
        }
        
        private func append<AnchorType>(_ anchor: NSLayoutAnchor<AnchorType>,
                                        to toAnchor: NSLayoutAnchor<AnchorType>,
                                        _ constant: CGFloat) -> Self {
            constraints.append(anchor.to(toAnchor, constant))
            return self
        }
        
        func width(to constant: CGFloat) -> Self {
            append(target.width, to: constant)
        }
        
        func width(to dimension: NSLayoutDimension, multiplier: CGFloat = 1) -> Self {
            append(target.width, to: dimension, multiplier: multiplier)
        }
        
        func height(to constant: CGFloat) -> Self {
            append(target.height, to: constant)
        }
        
        func height(to dimension: NSLayoutDimension, multiplier: CGFloat = 1) -> Self {
            append(target.height, to: dimension, multiplier: multiplier)
        }
        
        private func append(_ dimension: NSLayoutDimension,
                            to constant: CGFloat) -> Self {
            constraints.append(dimension.to(constant))
            return self
        }
        
        private func append(_ dimension: NSLayoutDimension,
                            to toDimension: NSLayoutDimension,
                            multiplier: CGFloat) -> Self {
            constraints.append(dimension.to(toDimension, multiplier: multiplier))
            return self
        }
    }
    
    func addSubviews(_ constraintsAppliers: ConstraintsApplier...) {
        constraintsAppliers.forEach {
            addSubview($0.target)
            $0.apply()
        }
    }
    
    func top(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).top(to: anchor, constant)
    }
    
    func bottom(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).bottom(to: anchor, constant)
    }
    
    func leading(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).leading(to: anchor, constant)
    }
    
    func trailing(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).trailing(to: anchor, constant)
    }
    
    func centerX(to anchor: NSLayoutXAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).centerX(to: anchor, constant)
    }
    
    func centerY(to anchor: NSLayoutYAxisAnchor, _ constant: CGFloat = 0) -> ConstraintsApplier {
        ConstraintsApplier(self).centerY(to: anchor, constant)
    }
    
    func width(to constant: CGFloat) -> ConstraintsApplier {
        ConstraintsApplier(self).width(to: constant)
    }
    
    func width(to dimension: NSLayoutDimension, multiplier: CGFloat = 1) -> ConstraintsApplier {
        ConstraintsApplier(self).width(to: dimension, multiplier: multiplier)
    }
    
    func height(to constant: CGFloat) -> ConstraintsApplier {
        ConstraintsApplier(self).height(to: constant)
    }
    
    func height(to dimension: NSLayoutDimension, multiplier: CGFloat = 1) -> ConstraintsApplier {
        ConstraintsApplier(self).height(to: dimension, multiplier: multiplier)
    }
}

extension UIView {
    var top: NSLayoutYAxisAnchor { topAnchor }
    var bottom: NSLayoutYAxisAnchor { bottomAnchor }
    
    var leading: NSLayoutXAxisAnchor { leadingAnchor }
    var trailing: NSLayoutXAxisAnchor { trailingAnchor }
    
    var centerX: NSLayoutXAxisAnchor { centerXAnchor }
    var centerY: NSLayoutYAxisAnchor { centerYAnchor }
    
    var width: NSLayoutDimension { widthAnchor }
    var height: NSLayoutDimension { heightAnchor }
}

extension UILayoutGuide {
    var top: NSLayoutYAxisAnchor { topAnchor }
    var bottom: NSLayoutYAxisAnchor { bottomAnchor }
    
    var leading: NSLayoutXAxisAnchor { leadingAnchor }
    var trailing: NSLayoutXAxisAnchor { trailingAnchor }
    
    var centerX: NSLayoutXAxisAnchor { centerXAnchor }
    var centerY: NSLayoutYAxisAnchor { centerYAnchor }
    
    var width: NSLayoutDimension { widthAnchor }
    var height: NSLayoutDimension { heightAnchor }
}

extension NSLayoutAnchor {
    @objc func to(_ anchor: NSLayoutAnchor<AnchorType>, _ constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(equalTo: anchor, constant: constant)
    }
}

extension NSLayoutDimension {
    func to(_ constant: CGFloat) -> NSLayoutConstraint {
        constraint(equalToConstant: constant)
    }
    
    func to(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1) -> NSLayoutConstraint {
        constraint(equalTo: dimension, multiplier: multiplier)
    }
}
