//
//  KeyboardHeight.swift
//  
//
//  Created by Иван Копиев on 15.09.2023.
//

import UIKit
import Combine
import Foundation

/**
 Example

 I want to adjust UIScrollView's contentInset to fit keyboard height.

        let keyboard = KeyboardHeight()
        private var subscriptions: Set<AnyCancellable> = []

        keyboard.$visibleHeight
            .sink { height in scrollView.contentInset.bottom = height }
            .store(in: &subscriptions)

 I want to adjust UIScrollView's contentOffset to fit keyboard height.

         let keyboard = KeyboardHeight()
         private var subscriptions: Set<AnyCancellable> = []

          keyboard.$willShowVisibleHeight
             .sink { keyboardVisibleHeight in scrollView.contentOffset.y += keyboardVisibleHeight }
             .store(in: &subscriptions)

I want to make UIToolbar move along with the keyboard in an interactive dismiss mode.

         let keyboard = KeyboardHeight()
         private var subscriptions: Set<AnyCancellable> = []

          keyboard.$visibleHeight
             .sink { [toolbar, view] keyboardVisibleHeight in
                scrollView.contentOffset.y += keyboardVisibleHeight
                toolbar.frame.origin.y = view.frame.height - toolbar.frame.height - keyboardVisibleHeight
            }.store(in: &subscriptions)

 If you're using Auto Layout, you have to capture the toolbar's bottom constraint and set constant to keyboard visible height.

         let keyboard = KeyboardHeight()
         private var subscriptions: Set<AnyCancellable> = []

          keyboard.$visibleHeight
             .sink { [toolbarBottomConstraint] keyboardVisibleHeight in
                toolbarBottomConstraint.constant = -1 * keyboardVisibleHeight
            }.store(in: &subscriptions)
    Note: In real world, you should use setNeedsLayout() and layoutIfNeeded() with animation block.
 */
@available(iOS 13.0, *)
public final class KeyboardHeight: NSObject {
    /// An observable keyboard frame.
    @Published public var frame: CGRect = .zero

    /// An observable visible height of keyboard. Emits keyboard height if the keyboard is visible
    /// or `0` if the keyboard is not visible.
    @Published public var visibleHeight: CGFloat = 0

    /// Same with `visibleHeight` but only emits values when keyboard is about to show. This is
    /// useful when adjusting scroll view content offset.
    @Published public var willShowVisibleHeight: CGFloat = 0

    /// An observable visibility of keyboard. Emits keyboard visibility
    /// when changed keyboard show and hide.
    @Published public var isHidden: Bool = true

    private let panRecognizer = UIPanGestureRecognizer()
    private var subscriptions: Set<AnyCancellable> = []

    public override init() {
        let keyboardWillChangeFrame = UIResponder.keyboardWillChangeFrameNotification
        let keyboardWillHide = UIResponder.keyboardWillHideNotification
        let keyboardFrameEndKey = UIResponder.keyboardFrameEndUserInfoKey
        let defaultFrame = CGRect(
            x: 0,
            y: UIScreen.main.bounds.height,
            width: UIScreen.main.bounds.width,
            height: 0
        )

        let frameVariable = CurrentValueSubject<CGRect, Never>(defaultFrame)
        super.init()
        frameVariable.removeDuplicates()
            .sink(weakObject: self) { $0?.frame = $1 }
            .store(in: &subscriptions)

        $frame.map { UIScreen.main.bounds.intersection($0).height }
            .sink(weakObject: self) { $0?.visibleHeight = $1 }
            .store(in: &subscriptions)

        $visibleHeight
            .scan((visibleHeight: 0, isShowing: false)) { lastState, newVisibleHeight in
                return (visibleHeight: newVisibleHeight, isShowing: lastState.visibleHeight == 0 && newVisibleHeight > 0)
            }
            .filter { state in state.isShowing }
            .map { state in state.visibleHeight }
            .sink(weakObject: self) { $0?.willShowVisibleHeight = $1 }
            .store(in: &subscriptions)

        $visibleHeight
            .map { $0 == 0 }
            .removeDuplicates()
            .sink(weakObject: self) { $0?.isHidden = $1 }
            .store(in: &subscriptions)

        // keyboard will change frame
        let willChangeFrame = NotificationCenter.default.publisher(for: keyboardWillChangeFrame)
            .compactMap { $0.userInfo?[keyboardFrameEndKey] as? NSValue }
            .compactMap { $0.cgRectValue }
            .map { frame -> CGRect in
                if frame.origin.y < 0 { // if went to wrong frame
                    var newFrame = frame
                    newFrame.origin.y = UIScreen.main.bounds.height - newFrame.height
                    return newFrame
                }
                return frame
            }

        // keyboard will hide
        let willHide = NotificationCenter.default.publisher(for: keyboardWillHide)
            .map { notification -> CGRect in
                let rectValue = notification.userInfo?[keyboardFrameEndKey] as? NSValue
                return rectValue?.cgRectValue ?? defaultFrame
            }
            .map { frame -> CGRect in
                if frame.origin.y < 0 { // if went to wrong frame
                    var newFrame = frame
                    newFrame.origin.y = UIScreen.main.bounds.height
                    return newFrame
                }
                return frame
            }

        let didPan = UIApplication.shared.windows.first?.gesture(.pan(panRecognizer))
            .combineLatest(frameVariable)
            .map { ($0.0.get(), $0.1) }
            .flatMap { (gestureRecognizer, frame) in
                guard case .changed = gestureRecognizer.state,
                      let window = UIApplication.shared.windows.first,
                      frame.origin.y < UIScreen.main.bounds.height
                else {
                    return Empty<CGRect, Never>(completeImmediately: true).eraseToAnyPublisher()
                }
                let origin = gestureRecognizer.location(in: window)
                var newFrame = frame
                newFrame.origin.y = max(origin.y, UIScreen.main.bounds.height - frame.height)
                return Just(newFrame).eraseToAnyPublisher()
            }.eraseToAnyPublisher()

        // merge into single sequence
        didPan?.merge(with: willChangeFrame, willHide)
            .sink { frameVariable.send($0) }
            .store(in: &subscriptions)

        // gesture recognizer
        self.panRecognizer.delegate = self
        self.panRecognizer.maximumNumberOfTouches = 1
    }
}

@available(iOS 13.0, *)
extension KeyboardHeight: UIGestureRecognizerDelegate {

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        let point = touch.location(in: gestureRecognizer.view)
        var view = gestureRecognizer.view?.hitTest(point, with: nil)
        while let candidate = view {
            if let scrollView = candidate as? UIScrollView,
               case .interactive = scrollView.keyboardDismissMode {
                return true
            }
            view = candidate.superview
        }
        return false
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === self.panRecognizer
    }

}
