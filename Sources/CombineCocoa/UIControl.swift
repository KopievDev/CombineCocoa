//
//  UIControl.swift
//  
//
//  Created by Иван Копиев on 15.09.2023.
//

import UIKit
import Combine

public extension UIControl {
    @available(iOS 13.0, *)
    struct EventPublisher: Publisher {
        public typealias Output = Void
        public typealias Failure = Never

        fileprivate var control: UIControl
        fileprivate var event: Event

        public func receive<S: Subscriber>(subscriber: S ) where S.Input == Output, S.Failure == Failure {
            let subscription = EventSubscription<S>()
            subscription.target = subscriber
            subscriber.receive(subscription: subscription)
            control.addTarget(subscription, action: #selector(subscription.trigger), for: event)
        }
    }
}

private extension UIControl {
    @available(iOS 13.0, *)
    class EventSubscription<Target: Subscriber>: Subscription where Target.Input == Void {

        var target: Target?

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
        }

        @objc func trigger() {
            let _ = target?.receive(())
        }
    }
}

@available(iOS 13.0, *)
public extension UIControl {
    /**
     Example

            let button = UIButton()
            private var subscriptions = Set<AnyCancellable>()

            button.publisher(for: .touchUpInside).sink {
                print("did tap on button")
            }.store(in: &subscriptions)
     */
    func publisher(for event: Event) -> EventPublisher {
        EventPublisher(control: self, event: event )
    }
}

@available(iOS 13.0, *)
public extension UIButton {
    /**
     Example

            let button = UIButton()
            private var subscriptions = Set<AnyCancellable>()

            button.tapPublisher.sink {
                print("did tap on button")
            }.store(in: &subscriptions)
     */
    var tapPublisher: EventPublisher {
        publisher(for: .touchUpInside)
    }
}

@available(iOS 13.0, *)
public extension UITextField {
        /**
         Example

                let textField = UITextField()
                private var subscriptions = Set<AnyCancellable>()

                textField.textPublisher.sink { text in
                     print(text)
                }.store(in: &subscriptions)
         */
        var textPublisher: AnyPublisher<String, Never> {
            publisher(for: .editingChanged)
                .map { [weak self] in self?.text ?? "" }
                .eraseToAnyPublisher()
        }
}
