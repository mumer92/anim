//
//  Animator-macos.swift
//  anim
//
//  Created by Onur Ersel on 2017-02-16.
//  Copyright (c) 2017 Onur Ersel. All rights reserved.

import Foundation
#if os(OSX)
import AppKit
#endif

#if os(OSX)
internal extension anim {

    /// Animator for macOS. `MacAnimator` uses the same technique to ease and stop animations
    /// with `ViewAnimator`. Only difference is this uses `NSAnimationContext` to run the animations.
    ///
    /// Please refer to its documentation for more information.
    internal class MacAnimator: Animator {

        internal struct AnimatingLayer {
            internal var layer: CALayer
            internal var key: String
        }

        static private let methodOriginal = class_getInstanceMethod(CALayer.self, #selector(CALayer.add))
        static private let methodSwizzled = class_getInstanceMethod(CALayer.self, #selector(CALayer.anim_add))

        static internal var activeInstance: MacAnimator?
        static internal var timingFunction: CAMediaTimingFunction?

        private var animatingLayers: [AnimatingLayer]? = []

        internal func startAnimation(animationClosure: @escaping  Closure,
                                     completion: @escaping Closure,
                                     settings: anim.Settings) {
            anim.log("running ViewAnimator")

            method_exchangeImplementations(MacAnimator.methodOriginal, MacAnimator.methodSwizzled)

            MacAnimator.activeInstance = self
            MacAnimator.timingFunction = settings.ease.caMediaTimingFunction

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current().duration = settings.duration
            animationClosure()
            NSAnimationContext.endGrouping()

            MacAnimator.activeInstance = nil
            MacAnimator.timingFunction = nil

            method_exchangeImplementations(MacAnimator.methodSwizzled, MacAnimator.methodOriginal)

            // Since there's no completion callback to be used with `NSAnimationContext`, it's
            // using `DispatchQueue` to call completion after animation duration.
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(settings.duration*1000)), execute: completion)
        }

        internal func stopAnimation() {
            animatingLayers?.forEach { animatingLayer in
                animatingLayer.layer.removeAnimation(forKey: animatingLayer.key)
            }
            cleanup()
        }

        private func cleanup() {
            animatingLayers?.removeAll()
            animatingLayers = nil
        }

        internal class func addLayerToAnimator(_ layer: CALayer, _ key: String) {
            MacAnimator.activeInstance?.animatingLayers?.append(AnimatingLayer(layer: layer, key: key))
        }

    }

}

fileprivate extension CALayer {
    @objc
    func anim_add(_ animation: CAAnimation, forKey key: String?) {
        animation.timingFunction = anim.MacAnimator.timingFunction
        anim.MacAnimator.addLayerToAnimator(self, key!)
        self.anim_add(animation, forKey: key)
    }
}
#endif
