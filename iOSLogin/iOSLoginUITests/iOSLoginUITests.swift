import XCTest

// ============================================================
//  iOSLoginUITests · 登录页 XCUITest 验收测试
//  通过 accessibility 树验证（不依赖像素渲染）
// ============================================================

final class iOSLoginUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    // MARK: - 阶段 2：静态 UI 元素齐全
    @MainActor
    func testLoginPageElementsExist() throws {
        let app = launchApp()

        // 头部
        XCTAssertTrue(app.staticTexts["欢迎回来"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["登录后享受更完整的功能体验"].exists)
        // 双 Tab
        XCTAssertTrue(app.buttons["密码登录"].exists)
        XCTAssertTrue(app.buttons["验证码登录"].exists)
        // 默认密码 Tab 表单
        XCTAssertTrue(app.textFields["请输入邮箱或账号"].exists)
        // 登录按钮初始禁用
        let loginBtn = app.buttons["登 录"]
        XCTAssertTrue(loginBtn.exists)
        XCTAssertFalse(loginBtn.isEnabled, "未填信息时登录按钮应为禁用态")
        // 底部入口
        XCTAssertTrue(app.buttons["忘记密码？"].exists)
        XCTAssertTrue(app.buttons["立即注册"].exists)
    }

    // MARK: - 阶段 5：密码登录全流程
    @MainActor
    func testPasswordLoginFlow() throws {
        let app = launchApp()

        let email = app.textFields["请输入邮箱或账号"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("demo@ios.app")

        let pwd = app.secureTextFields["6-20 位，含字母和数字"]
        pwd.tap()
        pwd.typeText("pass99word")

        // 未勾选协议时按钮仍禁用
        let loginBtn = app.buttons["登 录"]
        XCTAssertFalse(loginBtn.isEnabled, "未勾选协议时按钮应禁用")

        // 勾选协议后按钮启用
        app.buttons["agreementCheckbox"].tap()
        XCTAssertTrue(loginBtn.isEnabled, "勾选协议后按钮应启用")

        // 提交 → 成功遮罩出现 → 自动重置
        loginBtn.tap()
        XCTAssertTrue(app.staticTexts["登录成功"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["欢迎回来，开始探索吧"].waitForExistence(timeout: 3))
    }

    // MARK: - 阶段 4：验证码登录链路（倒计时 + OTP）
    @MainActor
    func testSMSCodeFlow() throws {
        let app = launchApp()

        // 切到验证码 Tab
        let smsTab = app.buttons["验证码登录"]
        XCTAssertTrue(smsTab.waitForExistence(timeout: 5))
        smsTab.tap()

        // 手机号输入（含清洗：非数字被过滤）
        let phone = app.textFields["请输入手机号"]
        XCTAssertTrue(phone.exists)
        phone.tap()
        phone.typeText("13800138000")

        // 发送验证码，倒计时出现
        let sendBtn = app.buttons["获取验证码"]
        XCTAssertTrue(sendBtn.exists)
        sendBtn.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '秒后重新获取'")).firstMatch
            .waitForExistence(timeout: 3), "点击发送后应进入倒计时状态")

        // 勾选协议后输入 6 位验证码
        app.buttons["agreementCheckbox"].tap()
        let otp = app.textFields["otpInput"]
        otp.tap()
        otp.typeText("482913")

        let loginBtn = app.buttons["登 录"]
        XCTAssertTrue(loginBtn.isEnabled, "手机号+验证码+协议齐备后按钮应启用")
    }

    // MARK: - 阶段 5：注册页入口过渡
    @MainActor
    func testRegisterNavigation() throws {
        let app = launchApp()

        let register = app.buttons["立即注册"]
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        register.tap()

        XCTAssertTrue(app.staticTexts["创建账号"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["填写以下信息，即刻开始体验"].exists)

        // 返回登录
        app.buttons["返回登录"].tap()
        XCTAssertTrue(app.staticTexts["欢迎回来"].waitForExistence(timeout: 3))
    }
}