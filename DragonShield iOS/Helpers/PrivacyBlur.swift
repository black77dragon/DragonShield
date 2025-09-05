#if os(iOS)
import SwiftUI

private struct PrivacyBlurModifier: ViewModifier {
    @AppStorage("privacy.blurValues") private var privacyBlur = false
    func body(content: Content) -> some View {
        // Use a stronger blur so large numbers cannot be guessed
        content.blur(radius: privacyBlur ? 18 : 0)
    }
}

extension View {
    func privacyBlur() -> some View { self.modifier(PrivacyBlurModifier()) }
}
#endif
