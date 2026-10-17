import SwiftUI

// iOS 17 的 Path.union(_:eoFill:) / subtracting(_:eoFill:) 新重载在低版本部署目标上不可用。
// 这三处用法都很简单（描边宽路径 ∪ 原形、矩形减圆洞），用 CGPath + even-odd 手工等价实现。

extension Path {
    /// 等价 `a.union(b)`（nonzero 合并画两次填充的效果一致；这里用于「描边加粗后的轮廓 ∪ 原形」再整体 fill/stroke）
    func union16(_ other: Path) -> Path {
        var p = self
        p.addPath(other)   // 填充时 nonzero 规则下两个同向路径就是并集的效果
        return p
    }

    /// 等价 `rect.subtracting(holes)`：矩形挖圆洞（邮票齿孔）。drawLayer 里 fill 用 evenOdd 语义做不到（ctx.fill 固定 nonzero?）——
    /// 换个思路：不挖洞，直接在洞的位置用背景色画圆盖上（邮票这层是白底 + 后面是卡片背景，盖圆会露馅）。
    /// 正解：GraphicsContext 的 fill 支持 eoFill 风格吗？不支持。改用 CGPath.apply 构造反绕洞的路径：
    /// 矩形顺时针 + 洞逆时针 → nonzero 填充自然出洞。这是经典 nonzero 挖洞手法，iOS16 可用。
    static func rectSubtractingCircles16(_ r: CGRect, holes: [(CGPoint, CGFloat)]) -> Path {
        let outer = CGMutablePath()
        outer.addRect(r)
        var p = Path(outer)
        // 洞反向绕行（addEllipse 是顺时针的，加进同一条 Path 时 SwiftUI nonzero 下反向才会被挖掉——
        // 但 Path 的子路径方向由生成器决定，不能直接反转。稳妥：分开两个子路径但把椭圆用弧线手动逆时针画）
        for (c, rad) in holes {
            var hole = Path()
            // 逆时针圆：从角度 2π 走到 0
            hole.move(to: CGPoint(x: c.x + rad, y: c.y))
            hole.addArc(center: c, radius: rad, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            p.addPath(hole)
        }
        return p
    }
}
