import SwiftUI
import UIKit

extension View {
    func dismissGuard(_ isActive: Bool, onAttempt: @escaping () -> Void) -> some View {
        background(DismissGuard(isActive: isActive, onAttempt: onAttempt).frame(width: 0, height: 0))
    }
}

private struct DismissGuard: UIViewControllerRepresentable {
    let isActive: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.relay.isActive = isActive
        controller.relay.onAttempt = onAttempt
        controller.install()
    }

    final class Controller: UIViewController {
        let relay = Relay()

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        private var sheet: UIViewController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let controller = current as? UIViewController, controller !== self,
                   controller.parent == nil, controller.presentingViewController != nil {
                    return controller
                }
                responder = current.next
            }
            return nil
        }

        func install() {
            sheet?.isModalInPresentation = relay.isActive
            guard let presentation = sheet?.presentationController,
                  presentation.delegate !== relay else { return }
            relay.original = presentation.delegate
            presentation.delegate = relay
        }
    }

    final class Relay: NSObject, UIAdaptivePresentationControllerDelegate {
        weak var original: UIAdaptivePresentationControllerDelegate?
        var isActive = false
        var onAttempt: () -> Void = {}

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt()
        }

        override func responds(to selector: Selector!) -> Bool {
            return super.responds(to: selector) || original?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
