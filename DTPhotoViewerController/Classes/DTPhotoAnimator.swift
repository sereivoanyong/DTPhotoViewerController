//
//  DTPhotoAnimator.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 04/05/16.
//  Copyright © 2016 Vo Duc Tung. All rights reserved.
//

import UIKit

@objc public enum DTPhotoAnimatorType: Int {
    case Dismissing = 0
    case Presenting = 1
}

///
/// If you wish to provide a custom transition animator, you just need to create a new class
/// that conforms this protocol and assign 
///
public protocol DTPhotoViewerBaseAnimator: NSObjectProtocol, UIViewControllerAnimatedTransitioning {
    var type: DTPhotoAnimatorType {get set}
    var presentingDuration: TimeInterval {get set}
    var dismissingDuration: TimeInterval {get set}
}

class DTPhotoAnimator: NSObject, DTPhotoViewerBaseAnimator {
    ///
    /// Preseting transition duration
    /// Default value is 0.2
    ///
    var presentingDuration: TimeInterval = 0.2
    
    ///
    /// Dismissing transition duration
    /// Default value is 0.5
    ///
    var dismissingDuration: TimeInterval = 0.2
    
    ///
    /// Type of animator
    /// Default value is Presenting
    ///
    var type = DTPhotoAnimatorType.Presenting
    
    ///
    /// Indicates if using spring animation
    /// Default value is true
    ///
    var spring = true
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        //return correct duration
        var duration = type == .Presenting ? presentingDuration : dismissingDuration
        if spring {
            //Spring animation's duration should be longer than normal animation
            duration = duration * 2.5
        }
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let duration = self.transitionDuration(using: transitionContext)
        
        if type == .Presenting {
            let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
            guard let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)! as? DTPhotoViewerController else {
                fatalError("view controller does not conform DTPhotoViewer")
            }
            let fromView = fromViewController.view
            let toView = toViewController.view
            
            let completeTransition: () -> () = {
                // Add subview before completing transition
                UIApplication.shared.delegate?.window??.addSubview(toViewController.view)
                
                let isCancelled = transitionContext.transitionWasCancelled
                transitionContext.completeTransition(!isCancelled)
                
                if isCancelled {
                    container.insertSubview(toView!, belowSubview: fromView!)
                }
            }
            
            container.addSubview(fromView!)
            container.addSubview(toView!)
            
            if spring {
                UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    //Animate image view to the center
                    toViewController.presentingAnimation()
                    }, completion: { (finished) in
                        toViewController.presentingEnded()
                        completeTransition()
                })
            }
            else {
                UIView.animate(withDuration: duration, animations: {
                    //Animate image view to the center
                    toViewController.presentingAnimation()
                }, completion: { (finished) in
                    //Hide status bar
                    toViewController.presentingEnded()
                    completeTransition()
                }) 
            }
            
        }
        else {
            guard let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) as? DTPhotoViewerController else {
                fatalError("view controller does not conform DTPhotoViewer")
            }
            
            let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
            let fromView = fromViewController.view
            let toView = toViewController.view
            
            let completeTransition: () -> () = {
                // Add subview before completing transition
                UIApplication.shared.delegate?.window??.addSubview(toViewController.view)
                
                let isCancelled = transitionContext.transitionWasCancelled
                transitionContext.completeTransition(!isCancelled)
                
                if isCancelled {
                    container.insertSubview(toView!, belowSubview: fromView!)
                }
            }
            
            container.addSubview(toView!)
            container.addSubview(fromView!)
            
            if spring {
                UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    //Animate image view to the center
                    fromViewController.dismissingAnimation()
                    }, completion: { (finished) in
                        //End transition
                        fromViewController.dismissingEnded()
                        completeTransition()
                })
            }
            else {
                UIView.animate(withDuration: duration, animations: {
                    //Animate image view to the center
                    fromViewController.dismissingAnimation()
                    
                }, completion: { (finished) in
                    //End transition
                    fromViewController.dismissingEnded()
                    completeTransition()
                }) 
            }
        }
    }
    
    func animationEnded(_ transitionCompleted: Bool) {
        
    }
}