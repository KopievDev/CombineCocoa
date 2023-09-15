//
//  File.swift
//  
//
//  Created by Иван Копиев on 15.09.2023.
//

import UIKit
import Combine

@available(iOS 13.0, *)
public struct GesturePublisher: Publisher {
    public typealias Output = GestureType
    public typealias Failure = Never
    private let view: UIView
    private let gestureType: GestureType
    public init(view: UIView, gestureType: GestureType) {
        self.view = view
        self.gestureType = gestureType
    }
    public func receive<S>(subscriber: S) where S : Subscriber,
    GesturePublisher.Failure == S.Failure, GesturePublisher.Output
    == S.Input {
        let subscription = GestureSubscription(
            subscriber: subscriber,
            view: view,
            gestureType: gestureType
        )
        subscriber.receive(subscription: subscription)
    }
}
public enum GestureType {
    case tap(UITapGestureRecognizer = .init())
    case swipe(UISwipeGestureRecognizer = .init())
    case longPress(UILongPressGestureRecognizer = .init())
    case pan(UIPanGestureRecognizer = .init())
    case pinch(UIPinchGestureRecognizer = .init())
    case edge(UIScreenEdgePanGestureRecognizer = .init())
    public func get() -> UIGestureRecognizer {
        switch self {
        case let .tap(tapGesture):
            return tapGesture
        case let .swipe(swipeGesture):
            return swipeGesture
        case let .longPress(longPressGesture):
            return longPressGesture
        case let .pan(panGesture):
            return panGesture
        case let .pinch(pinchGesture):
            return pinchGesture
        case let .edge(edgePanGesture):
            return edgePanGesture
       }
    }
}
@available(iOS 13.0, *)
final class GestureSubscription<S: Subscriber>: Subscription where S.Input == GestureType, S.Failure == Never {
    private var subscriber: S?
    private var gestureType: GestureType
    private var view: UIView
    init(subscriber: S, view: UIView, gestureType: GestureType) {
        self.subscriber = subscriber
        self.view = view
        self.gestureType = gestureType
        configureGesture(gestureType)
    }
    private func configureGesture(_ gestureType: GestureType) {
        let gesture = gestureType.get()
        gesture.addTarget(self, action: #selector(handler))
        view.addGestureRecognizer(gesture)
    }
    func request(_ demand: Subscribers.Demand) { }
    func cancel() {
        subscriber = nil
    }
    @objc
    private func handler() {
        _ = subscriber?.receive(gestureType)
    }
}

public extension UISwipeGestureRecognizer {
    convenience init(direction: UISwipeGestureRecognizer.Direction) {
        self.init()
        self.direction = direction
    }
}

@available(iOS 13.0, *)
public extension UIView {
    /**
     Example

         let someView = UIView()
         private var subscriptions = Set<AnyCancellable>()

         someView.gesture(.tap()).sink {
             print("did tap on view")
         }.store(in: &subscriptions)
     */
    func gesture(_ gestureType: GestureType = .tap()) ->
    GesturePublisher {
        .init(view: self, gestureType: gestureType)
    }
}
