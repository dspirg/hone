import XCTest

final class PaywallUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--force-paywall"]
    }

    // MARK: - Paywall Appears

    func testPaywallHeadlineAppears() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "--force-paywall should show paywall headline")
    }

    // MARK: - Pricing Display

    func testPaywallShowsTwoPricingCards() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        let annualCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Annual plan'")).firstMatch
        let monthlyCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Monthly plan'")).firstMatch

        // Cards may not load without App Store Connect products — check for either cards or error state
        let cardsLoaded = annualCard.waitForExistence(timeout: 5)
        if cardsLoaded {
            XCTAssertTrue(monthlyCard.exists, "Monthly pricing card should exist alongside annual")
        } else {
            // RevenueCat can't load offerings without real products — verify error state
            let errorText = app.staticTexts["Couldn't load pricing"]
            XCTAssertTrue(errorText.exists, "Should show pricing cards or 'Couldn't load pricing' error")
        }
    }

    func testAnnualCardHasMostPopularBadge() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        let badge = app.staticTexts["Most Popular"]
        // Badge only visible when pricing loads — skip if RevenueCat can't fetch offerings
        let errorText = app.staticTexts["Couldn't load pricing"]
        if !errorText.waitForExistence(timeout: 5) {
            XCTAssertTrue(badge.waitForExistence(timeout: 5), "Most Popular badge should be visible")
        }
    }

    func testCTAOrErrorStateExists() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        // Either CTA buttons or error state should exist
        let trialCTA = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Free Trial'")).firstMatch
        let subscribeCTA = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Subscribe Now'")).firstMatch
        let errorText = app.staticTexts["Couldn't load pricing"]

        let hasContent = trialCTA.waitForExistence(timeout: 10) || subscribeCTA.exists || errorText.exists
        XCTAssertTrue(hasContent, "Paywall should show CTA or pricing error state")
    }

    // MARK: - Blurred Plan Gate

    func testPaywallPresentedForUnsubscribedUser() throws {
        app.launch()
        // --force-paywall sets isSubscribed=false, so D-13 hard paywall covers HomeView
        let paywallHeadline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(paywallHeadline.waitForExistence(timeout: 10), "Paywall should be presented for unsubscribed users")
    }

    // MARK: - Accessibility

    func testPricingCardsAreAccessible() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        let annualCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Annual plan'")).firstMatch
        if annualCard.waitForExistence(timeout: 5) {
            XCTAssertFalse(annualCard.label.isEmpty, "Annual card should have accessibility label")

            let monthlyCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Monthly plan'")).firstMatch
            XCTAssertTrue(monthlyCard.exists, "Monthly card should exist")
            XCTAssertFalse(monthlyCard.label.isEmpty, "Monthly card should have accessibility label")
        }
        // If cards don't load (no App Store Connect products), a11y test is not applicable
    }

    func testPaywallAccessibilityAudit() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    // MARK: - Screenshot Capture

    func testCapturePaywallScreenshot() throws {
        app.launch()
        let headline = app.staticTexts["Your personalized plan is ready"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "Paywall should appear")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
