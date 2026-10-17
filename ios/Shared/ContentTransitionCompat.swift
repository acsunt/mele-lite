import SwiftUI

// iOS 16 兼容：contentTransition 的 .symbolEffect / .numericText 都是 17 里的。
// 16 上退回普通 .identity（不做数字/图标过渡动画，显示结果一样）。

extension ContentTransition {
    /// iOS 17 的 .symbolEffect(.replace)；16 上退回 identity
    static var symbolReplace16: ContentTransition {
        if #available(iOS 17.0, *) { return .symbolEffect(.replace) }
        return .identity
    }

    /// iOS 17 的 .numericText()；16 上退回 identity
    static var numericText16: ContentTransition {
        if #available(iOS 16.0, *) { return .numericText() }   // numericText 本身 iOS16 就有
        return .identity
    }
}

extension View {
    /// iOS17/18 的 containerBackground(_:for: .navigation)；16 上没有这个概念，什么都不做
    /// （.navigation 这个 ContainerBackgroundPlacement 值本身是 18 才有的，门槛提到 18）
    @ViewBuilder
    func containerBackgroundCompat<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 18.0, *) {
            self.containerBackground(style, for: .navigation)
        } else {
            self
        }
    }
}
