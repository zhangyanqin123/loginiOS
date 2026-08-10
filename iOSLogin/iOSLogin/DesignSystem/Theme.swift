import SwiftUI

// ============================================================
//  DesignSystem · 设计令牌
//  与 index.html 的 CSS 变量 / README.md「设计令牌 → iOS 映射」一一对应
// ============================================================

// MARK: - 颜色工具
extension Color {
    /// 从 0xRRGGBB 十六进制构建颜色。例：Color(hex: 0x5B7CFF)
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - 设计令牌
enum Theme {

    // MARK: 品牌色
    static let primary      = Color(hex: 0x5B7CFF)   // --c-primary-500
    static let primary600   = Color(hex: 0x4A6CF0)   // --c-primary-600 按压态
    static let primary700   = Color(hex: 0x3D5CE0)   // --c-primary-700 深按压
    static let secondary    = Color(hex: 0x8A5CFF)   // --c-secondary-500
    static let gradient     = LinearGradient(colors: [primary, secondary],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing)

    // MARK: 中性色
    static let bg           = Color(hex: 0xF7F8FC)   // --c-bg 页面背景
    static let surface      = Color.white             // --c-surface
    static let surfaceMuted = Color(hex: 0xF3F4F8)   // --c-surface-muted
    static let text1        = Color(hex: 0x1A1D2B)   // --c-text-1
    static let text2        = Color(hex: 0x5A6072)   // --c-text-2
    static let text3        = Color(hex: 0x9AA1B2)   // --c-text-3
    static let border       = Color(hex: 0xE6E8F0)   // --c-border
    static let border2      = Color(hex: 0xD5D9E5)   // --c-border-2

    // MARK: 功能色
    static let success      = Color(hex: 0x34C759)   // --c-success
    static let error        = Color(hex: 0xFF3B30)   // --c-error
    static let errorBg      = Color(hex: 0xFFF0EF)   // --c-error-bg
    static let toastBg      = Color.black.opacity(0.88)
    static let dim          = Color.black.opacity(0.5)

    // MARK: 聚焦光环
    static let focusRing    = Color.primary.opacity(0.16)
    static let errorRing    = Color(hex: 0xFF3B30).opacity(0.12)

    // MARK: 圆角
    static let radiusInput:   CGFloat = 14   // --r-input
    static let radiusCard:    CGFloat = 20   // --r-card
    static let radiusButton:  CGFloat = 28   // --r-btn
    static let radiusModal:   CGFloat = 24   // --r-modal
    static let radiusOTP:     CGFloat = 12   // --r-otp
    static let radiusCheckbox:CGFloat = 7    // 勾选框
    static let radiusPill:    CGFloat = 999  // --r-pill

    // MARK: 阴影
    static let shadowButton = Color.primary.opacity(0.38)   // --shadow-btn
    static let shadowCard   = Color.black.opacity(0.08)     // --shadow-card
    static let shadowToast  = Color.black.opacity(0.16)     // --shadow-toast
    static let shadowModal  = Color.black.opacity(0.18)     // --shadow-modal

    // MARK: 间距刻度（4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 40 / 48）
    static let pagePadding:  CGFloat = 24
    static let fieldSpacing: CGFloat = 18
    static let tabHeight:    CGFloat = 52
    static let fieldHeight:  CGFloat = 54
    static let buttonHeight: CGFloat = 56
    static let otpCellHeight:CGFloat = 54

    // MARK: 字号
    static let fontHero    = Font.system(size: 34, weight: .bold)     // --fs-hero
    static let fontTitle   = Font.system(size: 22, weight: .bold)     // 弹窗标题
    static let fontBody    = Font.system(size: 17)                    // --fs-body
    static let fontInput   = Font.system(size: 15, weight: .medium)   // --fs-input
    static let fontCaption = Font.system(size: 13)                    // --fs-caption
    static let fontMicro   = Font.system(size: 12)                    // --fs-micro
    static let fontButton  = Font.system(size: 17, weight: .semibold) // --fs-btn

    // MARK: 动效时长（与 index.html 的 --dur-* 对齐）
    static let durFast:  CGFloat = 0.15
    static let durBase:  CGFloat = 0.25
    static let durSlow:  CGFloat = 0.42
}