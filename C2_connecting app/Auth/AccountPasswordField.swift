import SwiftUI
import UIKit

/// Keeps UIKit's secure editing buffer stable while SwiftUI updates form validation.
struct AccountPasswordField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let accessibilityID: String
    let accessibilityName: String
    let onFocus: () -> Void
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.placeholder = placeholder
        field.accessibilityIdentifier = accessibilityID
        field.accessibilityLabel = accessibilityName
        field.keyboardType = .asciiCapable
        // Keep password AutoFill while avoiding the new-password suggestion
        // path that replaces manual input in the supported iOS runtime.
        field.textContentType = .password
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(Color.naldamInk)
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace), UIBarButtonItem(title: "입력 완료", style: .done, target: context.coordinator, action: #selector(Coordinator.finishEditing))]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        context.coordinator.field = field
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.isEnabled != isEnabled { field.isEnabled = isEnabled }
        // Editing changes flow out through the delegate. Replacing the native
        // buffer on every SwiftUI render can reset secure text selection.
        if !field.isFirstResponder, field.text != text { field.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AccountPasswordField
        weak var field: UITextField?
        init(_ parent: AccountPasswordField) { self.parent = parent }
        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }
        @objc func finishEditing() { field?.resignFirstResponder() }
        func textFieldDidBeginEditing(_ field: UITextField) {
            DispatchQueue.main.async { [weak self] in self?.parent.onFocus() }
        }
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            parent.onSubmit()
            return false
        }
    }
}
