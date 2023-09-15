import UIKit
import Combine

@available(iOS 13.0, *)
public extension UIViewController {

    func withCloseKeyboardWhenTap() -> AnyCancellable {
        view.gesture()
            .sink(weakObject: self) { vc, _ in vc?.view.endEditing(true) }
    }
}

@available(iOS 13.0, *)
extension Publisher where Failure == Never {

    public func weakAssign<T: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<T, Output>,
        on object: T
    ) -> AnyCancellable {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }

    public func sink<T: AnyObject>(
        weakObject: T,
        receiveValue: @escaping ((T?, Self.Output) -> Void)
    ) -> AnyCancellable {
        sink { [weak weakObject] value in
            receiveValue(weakObject, value)
        }
    }

    public func sink<T: AnyObject>(
        unownedObject: T,
        receiveValue: @escaping ((T, Self.Output) -> Void)
    ) -> AnyCancellable {
        sink { [unowned unownedObject] value in
            receiveValue(unownedObject, value)
        }
    }
}
