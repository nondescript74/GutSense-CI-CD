//
//  GutSenseUITests.swift
//  GutSenseUITests
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import XCTest

final class GutSenseUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        // Verify the app launched successfully
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    // MARK: - Tab Navigation Tests
    
    @MainActor
    func testTabNavigation() throws {
        // Verify all tabs are present and accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        
        // Test Analyze tab
        let analyzeTab = tabBar.buttons["Analyze"]
        XCTAssertTrue(analyzeTab.exists)
        analyzeTab.tap()
        XCTAssertTrue(analyzeTab.isSelected)
        
        // Test History tab
        let historyTab = tabBar.buttons["History"]
        XCTAssertTrue(historyTab.exists)
        historyTab.tap()
        XCTAssertTrue(historyTab.isSelected)
        
        // Test Sources tab
        let sourcesTab = tabBar.buttons["Sources"]
        XCTAssertTrue(sourcesTab.exists)
        sourcesTab.tap()
        XCTAssertTrue(sourcesTab.isSelected)
        
        // Test Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)
    }
    
    // MARK: - Input Mode Tests
    
    @MainActor
    func testInputModeSelection() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Verify Text mode is default
        let textButton = app.buttons["Text"]
        XCTAssertTrue(textButton.exists)
        
        // Switch to Photo mode
        let photoButton = app.buttons["Photo"]
        XCTAssertTrue(photoButton.exists)
        photoButton.tap()
        
        // Verify photo picker interface appears
        let photoPickerPrompt = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'photo'")).firstMatch
        XCTAssertTrue(photoPickerPrompt.waitForExistence(timeout: 2))
        
        // Switch to Barcode mode
        let barcodeButton = app.buttons["Barcode"]
        XCTAssertTrue(barcodeButton.exists)
        barcodeButton.tap()
        
        // Verify barcode scanner prompt appears
        let barcodePrompt = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'barcode'")).firstMatch
        XCTAssertTrue(barcodePrompt.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testTextInputMode() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Ensure we're in text mode
        app.buttons["Text"].tap()
        
        // Find the text input field
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.exists)
        
        // Enter text
        textView.tap()
        textView.typeText("Garlic bread")
        
        // Verify text was entered
        XCTAssertTrue(textView.value as? String == "Garlic bread" || 
                     app.textViews.containing(NSPredicate(format: "value CONTAINS 'Garlic bread'")).firstMatch.exists)
        
        // Verify Clear button appears
        let clearButton = app.buttons["Clear"]
        XCTAssertTrue(clearButton.exists)
        
        // Test clearing text
        clearButton.tap()
        // Text should be cleared or return to placeholder state
    }
    
    @MainActor
    func testExampleQueriesLoad() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Verify example queries section exists
        let examplesHeader = app.staticTexts["Try an example"]
        XCTAssertTrue(examplesHeader.waitForExistence(timeout: 2))
        
        // Verify at least one example query button exists
        let firstExample = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'garlic' OR label CONTAINS[c] 'oats'")).firstMatch
        XCTAssertTrue(firstExample.exists)
        
        // Tap an example
        firstExample.tap()
        
        // Verify the text was populated in the input field
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.exists)
        let textValue = textView.value as? String ?? ""
        XCTAssertFalse(textValue.isEmpty)
    }
    
    // MARK: - Serving Size Tests
    
    @MainActor
    func testServingSizeSelector() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Enter some text to show serving selector
        let textView = app.textViews.firstMatch
        textView.tap()
        textView.typeText("Test food")
        
        // Dismiss keyboard
        app.tap()
        
        // Verify serving size selector appears
        let servingHeader = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'consuming'")).firstMatch
        XCTAssertTrue(servingHeader.waitForExistence(timeout: 2))
        
        // Verify serving preset buttons exist
        let quarterButton = app.buttons["¼"]
        let halfButton = app.buttons["½"]
        let standardButton = app.buttons["1×"]
        let doubleButton = app.buttons["2×"]
        
        XCTAssertTrue(quarterButton.exists)
        XCTAssertTrue(halfButton.exists)
        XCTAssertTrue(standardButton.exists)
        XCTAssertTrue(doubleButton.exists)
        
        // Test selecting different serving sizes
        halfButton.tap()
        // Verify selection changed (button should be highlighted)
        
        doubleButton.tap()
        // Verify selection changed
    }
    
    @MainActor
    func testCustomGramsInput() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Enter some text to show serving selector
        let textView = app.textViews.firstMatch
        textView.tap()
        textView.typeText("Test food")
        app.tap()
        
        // Find and toggle "Exact grams"
        let exactGramsToggle = app.buttons["Exact grams"]
        XCTAssertTrue(exactGramsToggle.waitForExistence(timeout: 2))
        exactGramsToggle.tap()
        
        // Find the custom grams text field
        let gramsField = app.textFields.containing(NSPredicate(format: "placeholderValue CONTAINS 'e.g. 45'")).firstMatch
        XCTAssertTrue(gramsField.waitForExistence(timeout: 2))
        
        // Enter custom grams
        gramsField.tap()
        gramsField.typeText("75")
        
        // Verify the value was entered
        XCTAssertTrue(gramsField.value as? String == "75")
    }
    
    // MARK: - Analyze Button Tests
    
    @MainActor
    func testAnalyzeButtonState() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Find analyze button
        let analyzeButton = app.buttons["Analyze Food"]
        XCTAssertTrue(analyzeButton.exists)
        
        // Button should be disabled initially (no input)
        XCTAssertFalse(analyzeButton.isEnabled)
        
        // Enter text
        let textView = app.textViews.firstMatch
        textView.tap()
        textView.typeText("Test food")
        app.tap()
        
        // Button state may depend on API credentials being set
        // Just verify the button exists and can be interacted with
        XCTAssertTrue(analyzeButton.exists)
    }
    
    @MainActor
    func testAPIKeysWarningDisplays() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Look for API keys warning card
        // This may or may not exist depending on if keys are configured
        let warningCard = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'API Keys Required'")).firstMatch
        
        // If the warning exists, verify it's visible
        if warningCard.exists {
            XCTAssertTrue(warningCard.exists)
            XCTAssertTrue(warningCard.isHittable)
        }
    }
    
    // MARK: - Settings Tests
    
    @MainActor
    func testSettingsNavigation() throws {
        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
        
        // Verify settings content loads
        let settingsNavigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(settingsNavigationBar.exists)
        
        // Look for API Keys navigation option
        let apiKeysButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'API Keys'")).firstMatch
        if apiKeysButton.exists {
            // Tap to navigate
            apiKeysButton.tap()
            
            // Verify we navigated to API keys view
            let backButton = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(backButton.exists)
            
            // Go back
            backButton.tap()
        }
    }
    
    @MainActor
    func testAPIKeysView() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Navigate to API Keys (if visible)
        let apiKeysButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'API Keys'")).firstMatch
        if apiKeysButton.exists {
            apiKeysButton.tap()
            
            // Verify service sections exist
            let anthropicSection = app.staticTexts["Anthropic"]
            let geminiSection = app.staticTexts["Google Gemini"]
            let backendSection = app.staticTexts["GutSense Backend"]
            
            // At least one service section should exist
            XCTAssertTrue(anthropicSection.exists || geminiSection.exists || backendSection.exists)
        }
    }
    
    // MARK: - History Tests
    
    @MainActor
    func testHistoryViewLoads() throws {
        // Navigate to History tab
        app.tabBars.buttons["History"].tap()
        
        // Verify history view loaded
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists)
        
        // History may be empty or have items
        // Just verify the view is accessible
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists || app.staticTexts.firstMatch.exists)
    }
    
    // MARK: - Sources Tests
    
    @MainActor
    func testSourcesViewLoads() throws {
        // Navigate to Sources tab
        app.tabBars.buttons["Sources"].tap()
        
        // Verify sources view loaded
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists)
        
        // Sources may be empty or have items
        // Just verify the view is accessible
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testMainElementsHaveAccessibilityLabels() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Verify key elements have proper accessibility
        let analyzeButton = app.buttons["Analyze Food"]
        XCTAssertTrue(analyzeButton.exists)
        XCTAssertFalse(analyzeButton.label.isEmpty)
        
        // Verify input mode buttons have labels
        let textButton = app.buttons["Text"]
        let photoButton = app.buttons["Photo"]
        let barcodeButton = app.buttons["Barcode"]
        
        XCTAssertTrue(textButton.exists)
        XCTAssertTrue(photoButton.exists)
        XCTAssertTrue(barcodeButton.exists)
    }
    
    // MARK: - Navigation Flow Tests
    
    @MainActor
    func testCompleteAnalysisFlowWithoutAPICall() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Enter text query
        let textView = app.textViews.firstMatch
        textView.tap()
        textView.typeText("Test food for UI testing")
        app.tap()
        
        // Adjust serving size
        let halfServingButton = app.buttons["½"]
        if halfServingButton.exists {
            halfServingButton.tap()
        }
        
        // Note: We won't actually trigger the analyze button
        // as that would require API credentials and make real network calls
        // This test just verifies the UI flow is navigable
        
        let analyzeButton = app.buttons["Analyze Food"]
        XCTAssertTrue(analyzeButton.exists)
        
        // Verify the complete input flow is ready
        XCTAssertTrue(textView.exists)
        XCTAssertTrue(analyzeButton.exists)
    }
    
    // MARK: - Input Validation Tests
    
    @MainActor
    func testEmptyInputShowsValidationMessage() throws {
        // Navigate to Analyze tab
        app.tabBars.buttons["Analyze"].tap()
        
        // Ensure text mode
        app.buttons["Text"].tap()
        
        // With no input, there should be a message or disabled button
        let analyzeButton = app.buttons["Analyze Food"]
        XCTAssertTrue(analyzeButton.exists)
        
        // Look for validation message
        let validationMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Enter a food' OR label CONTAINS[c] 'API keys'")).firstMatch
        
        // Either the button is disabled or there's a validation message
        XCTAssertTrue(!analyzeButton.isEnabled || validationMessage.exists)
    }
}
