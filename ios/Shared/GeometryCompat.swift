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

/// 朋友圈下拉刷新。18 的 onScrollGeometryChange / onScrollPhaseChange；16/17 用 UIKit scrollView 兜底：
/// 找到宿主 scrollView 观察.contentOffset。refreshing 时眯着眼睛等 load 完。
struct PullToRefreshCompat16: ViewModifier {
    @Binding var pull: CGFloat
    @Binding var refreshing: Bool
    let onRefresh: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { g in g.contentOffset.y + g.contentInsets.top } action: { _, y in
                    pull = max(0, -y)
                }
                .onScrollPhaseChange { old, new in
                    if old == .interacting, new != .interacting, pull > 70, !refreshing {
                        refreshing = true
                        onRefresh()
                    }
                }
        } else {
            content.background(ScrollOffsetReader(pull: $pull, refreshing: $refreshing, onRefresh: onRefresh))
        }
    }
}

/// 挂在背景里找最近的 UIScrollView，看它的 offset 判断下拉
private struct ScrollOffsetReader: UIViewRepresentable {
    @Binding var pull: CGFloat
    @Binding var refreshing: Bool
    let onRefresh: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        context.coordinator.attach(from: v)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onRefresh = onRefresh
        context.coordinator.refreshing = refreshing
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: ScrollOffsetReader
        var onRefresh: () -> Void = {}
        var refreshing = false
        private var obs: NSKeyValueObservation?
        private var wasInteracting = false

        init(_ parent: ScrollOffsetReader) { self.parent = parent }
        deinit { obs?.invalidate() }

        func attach(from view: UIView) {
            // 找上层第一个 scrollView（朋友圈页就是全屏那条）
            var p: UIView? = view.superview
            while p != nil, !(p is UIScrollView) { p = p?.superview }
            guard let scroll = p as? UIScrollView else { return }
            obs = scroll.observe(\.contentOffset, options: [.new]) { [weak self] sc, _ in
                guard let self else { return }
                let y = sc.contentOffset.y + sc.adjustedContentInset.top
                self.parent.pull = max(0, -y)
                let interacting = sc.isTracking || sc.isDecelerating
                if self.wasInteracting, !interacting, self.parent.pull > 70, !self.refreshing {
                    self.refreshing = true
                    self.onRefresh()
                }
                self.wasInteracting = interacting
            }
        }
    }
}

/// 阅读器翻页进度：滚动位置换算第几页。18 的 onScrollGeometryChange；低版本用 KVO 看 scrollView。
struct PageProgressCompat16: ViewModifier {
    let onChange: ([CGFloat]) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: [CGFloat].self) { g in
                [g.contentOffset.y, g.contentSize.height, g.containerSize.height]
            } action: { _, v in onChange(v) }
        } else {
            content.background(ScrollMetricsReader(onChange: onChange))
        }
    }
}

private struct ScrollMetricsReader: UIViewRepresentable {
    let onChange: ([CGFloat]) -> Void

    init(onChange: @escaping ([CGFloat]) -> Void) {
        self.onChange = onChange
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        context.coordinator.attach(from: v)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.report()   // id(current) 换章重建后立报一次
    }
    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject {
        var onChange: ([CGFloat]) -> Void = { _ in }
        private var obs: NSKeyValueObservation?
        private weak var scroll: UIScrollView?

        init(onChange: @escaping ([CGFloat]) -> Void) {
            self.onChange = onChange
        }

        deinit { obs?.invalidate() }

        func attach(from view: UIView) {
            var p: UIView? = view.superview
            while p != nil, !(p is UIScrollView) { p = p?.superview }
            guard let scroll = p as? UIScrollView else { return }
            self.scroll = scroll
            obs = scroll.observe(\.contentOffset, options: [.new]) { [weak self] sc, _ in self?.report(sc) }
            // 内容高度变化（翻页排版长出来）也要跟
            obs = scroll.observe(\.contentSize, options: [.new]) { [weak self] sc, _ in self?.report(sc) }
        }

        func report(_ sc: UIScrollView? = nil) {
            guard let sc = sc ?? scroll else { return }
            onChange([sc.contentOffset.y, sc.contentSize.height, sc.bounds.height])
        }
    }
}
