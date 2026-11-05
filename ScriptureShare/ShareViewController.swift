import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            let shared = await sharedText()
            let host = UIHostingController(rootView: ShareVerseView(
                pasted: PastedVerse.parse(shared),
                packs: SharedVerseInbox.packs,
                onCancel: { [weak self] in self?.finish() },
                onAdd: { [weak self] draft in
                    SharedVerseInbox.append(draft)
                    self?.finish()
                }
            ))
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func sharedText() async -> String {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { item -> [NSItemProvider] in
                var all = item.attachments ?? []
                if let text = item.attributedContentText?.string, !text.isEmpty {
                    all.insert(NSItemProvider(object: text as NSString), at: 0)
                }
                return all
            }
        var parts: [String] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                if !parts.contains(text) { parts.append(text) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                      let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                parts.append(url.absoluteString)
            }
        }
        return parts.joined(separator: "\n")
    }
}
