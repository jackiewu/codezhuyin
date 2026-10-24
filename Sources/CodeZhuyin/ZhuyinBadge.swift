import Cocoa
import SwiftUI

/// 組字區顯示原始按鍵時（ui、su），在按鍵正下方標出它對應的注音（ㄧㄛ、ㄋㄧ）。
/// 純顯示、不吃滑鼠；跟 ModeHUD 一樣是常駐單例，每次按鍵只換內容與位置。
final class ZhuyinBadge {
    static let shared = ZhuyinBadge()

    private let panel: NSPanel
    private let hosting = NSHostingView(rootView: AnyView(EmptyView()))

    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 24),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = hosting
    }

    func show(_ zhuyin: String, near lineRect: NSRect) {
        guard lineRect != .zero else { hide(); return }  // 拿不到位置就不畫，免得飄在螢幕角落
        hosting.rootView = AnyView(
            Text(zhuyin)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.brand)
                )
                .fixedSize()
        )
        let size = hosting.fittingSize
        var origin = NSPoint(x: lineRect.minX, y: lineRect.minY - 4 - size.height)
        let screen = NSScreen.screens.first { NSPointInRect(lineRect.origin, $0.frame) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            if origin.y < visible.minY { origin.y = lineRect.maxY + 4 }
            origin.x = min(max(visible.minX, origin.x), visible.maxX - size.width)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
