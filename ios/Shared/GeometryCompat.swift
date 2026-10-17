import SwiftUI

// iOS 17 的 .onGeometryChange 在 iOS 16 上没有：用 GeometryReader + preference 兜底。
// 三个后缀对齐三种用法：frame(按 key 取 framein) / height / contains-screen 判断。
// 用法照搬原调用点，iOS 17+ 直接走系统原版（GeometryCompat.swift 里同名扩展会冲突时以此为准）。

// MARK: - iOS 16 兜底：onGeometryChange

extension View {
    /// 等价 iOS17 的 `onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action:`（16 兼容）
    @ViewBuilder
    func onGeometryChange16(for type: CGRect.Type,
                            action: @escaping (CGRect) -> Void) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { action(geo.frame(in: .global)) }
                .onChange(of: geo.frame(in: .global)) { f in action(f) }
        }
        .overlay(self)
    }

    /// 等价 iOS17 的 `onGeometryChange(for: CGFloat.self) { $0.size.height } action:`（16 兜底）
    @ViewBuilder
    func onHeightChange16(action: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPrefKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPrefKey.self, perform: action)
    }

    /// 等价 iOS17 的「视口内吗」判断（16 兜底）
    @ViewBuilder
    func onScreen16(action: @escaping (Bool) -> Void) -> some View {
        background(
            GeometryReader { geo in
                let visible = geo.frame(in: .global).intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
                Color.clear.onAppear { action(visible) }
                    .onChange(of: geo.frame(in: .global)) { f in
                        action(f.intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size)))
                    }
            }
        )
    }
}

struct HeightPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 聊天头部的底线 Y（global 坐标）。iOS17+ 原版 onGeometryChange；16 用 GeometryReader 兜底。
struct HeaderBottomReader16: ViewModifier {
    let action: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { action($0) }
        } else {
            content.background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeaderMaxYKey.self, value: geo.frame(in: .global).maxY)
                }
            )
            .onPreferenceChange(HeaderMaxYKey.self, perform: action)
        }
    }
}

struct HeaderMaxYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// cell 渲染出来的高度（异步图长出来后重排用）。同样双版本。
struct RowHeightReader16: ViewModifier {
    let action: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { action($0) }
        } else {
            content.background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeightPrefKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeightPrefKey.self, perform: action)
        }
    }
}

/// 是不是在屏幕上（主屏翻页挂着不渲染）。同样双版本。
struct OnScreenReader16: ViewModifier {
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .global).intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
            } action: { action($0) }
        } else {
            content.background(
                GeometryReader { geo in
                    let visible = geo.frame(in: .global).intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
                    Color.clear.onAppear { action(visible) }
                        .onChange(of: geo.frame(in: .global)) { f in
                            action(f.intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size)))
                        }
                }
            )
        }
    }
}

/// 相册胶片条：行在屏幕上的位置（global frame）。同样双版本。
struct StripFrameReader16: ViewModifier {
    let action: (CGRect) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { action($0) }
        } else {
            content.background(
                GeometryReader { geo in
                    Color.clear.preference(key: StripFrameKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(StripFrameKey.self, perform: action)
        }
    }
}

struct StripFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// iOS17 的 containerRelativeFrame(.vertical) { 铺满 }；16 用屏幕高度直接撑（这页是全屏 overlay，等价）
struct FullHeightFrame16: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerRelativeFrame(.vertical, alignment: .top) { h, _ in h }
        } else {
            content.frame(height: UIScreen.main.bounds.height)
        }
    }
}
