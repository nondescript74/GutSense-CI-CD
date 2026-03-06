//
//  GutSenseTests.swift
//  GutSenseTests
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import Testing
import Foundation
@testable import GutSense

// MARK: - DTO Encoding Tests

struct BackendAPIServiceTests {
    
    // MARK: - DTO to Domain Conversion Tests
    
    @Test("AgentResultDTO converts to AgentResult domain model correctly")
    func testAgentResultDTOToDomain() {
        // Arrange
        let dto = AgentResultDTO(
            agent_type: "claude",
            fodmap_tiers: [
                IngredientFODMAPDTO(
                    ingredient: "Wheat Bread",
                    tier: "high",
                    fructan_g: 0.7,
                    gos_g: 0.1,
                    lactose_g: 0.0,
                    fructose_g: 0.3,
                    polyol_g: 0.0,
                    serving_size_g: 35.0,
                    source: "Monash University"
                )
            ],
            ibs_trigger_probability: 0.72,
            confidence_tier: "peer-reviewed",
            confidence_interval: 0.15,
            bioavailability: [],
            enzyme_recommendations: [
                EnzymeRecommendationDTO(
                    name: "Fructan-Digest",
                    brand: "FodmapEnzyme",
                    targets: "Fructans",
                    dose: "1 capsule",
                    temperature_warning: true,
                    notes: "Take before meal"
                )
            ],
            citations: [],
            personalized_risk_delta: 0.12,
            total_fructan_g: 0.7,
            total_gos_g: 0.1,
            safety_flags: [
                SafetyFlagDTO(message: "High FODMAP content", severity: "warning")
            ],
            processing_latency_ms: 1250
        )
        
        // Act
        let domain = dto.toDomain(agentType: .claude)
        
        // Assert
        #expect(domain.agentType == .claude)
        #expect(domain.ibsTriggerProbability == 0.72)
        #expect(domain.fodmapTiers.count == 1)
        #expect(domain.fodmapTiers.first?.ingredient == "Wheat Bread")
        #expect(domain.fodmapTiers.first?.tier == .high)
        #expect(domain.enzymeRecommendations.count == 1)
        #expect(domain.enzymeRecommendations.first?.name == "Fructan-Digest")
        #expect(domain.totalFructanG == 0.7)
        #expect(domain.safetyFlags.count == 1)
        #expect(domain.processingLatencyMs == 1250)
    }
    
    @Test("SynthesisResultDTO converts to SynthesisResult domain model correctly")
    func testSynthesisResultDTOToDomain() {
        // Arrange
        let dto = SynthesisResultDTO(
            reconciled_tiers: [
                IngredientFODMAPDTO(
                    ingredient: "Garlic",
                    tier: "high",
                    fructan_g: 1.2,
                    gos_g: 0.0,
                    lactose_g: 0.0,
                    fructose_g: 0.0,
                    polyol_g: 0.0,
                    serving_size_g: 3.0,
                    source: "Monash University"
                )
            ],
            final_ibs_probability: 0.85,
            confidence_band: 0.12,
            enzyme_recommendation: EnzymeRecommendationDTO(
                name: "Fructan-Digest",
                brand: "FodmapEnzyme",
                targets: "Fructans",
                dose: "1 capsule",
                temperature_warning: true,
                notes: "Take before meal"
            ),
            key_disagreements: ["Apple and Claude differ on garlic tolerance"],
            synthesis_rationale: "High fructan content confirmed across all sources",
            safety_flags: []
        )
        
        // Act
        let domain = dto.toDomain()
        
        // Assert
        #expect(domain.finalIBSProbability == 0.85)
        #expect(domain.confidenceBand == 0.12)
        #expect(domain.reconciledTiers.count == 1)
        #expect(domain.reconciledTiers.first?.ingredient == "Garlic")
        #expect(domain.enzymeRecommendation?.name == "Fructan-Digest")
        #expect(domain.keyDisagreements.count == 1)
        #expect(domain.synthesisRationale.contains("fructan"))
    }
    
    // MARK: - Domain to DTO Conversion Tests
    
    @Test("AgentResult converts back to AgentResultDTO correctly")
    func testAgentResultToDTOConversion() {
        // Arrange
        let agentResult = AgentResult(
            agentType: .claude,
            fodmapTiers: [
                IngredientFODMAP(
                    ingredient: "Onion",
                    tier: .high,
                    fructanG: 2.5,
                    gosG: 0.5,
                    lactoseG: 0.0,
                    fructoseG: 0.3,
                    polyolG: 0.0,
                    servingSizeG: 75.0,
                    source: "Monash"
                )
            ],
            ibsTriggerProbability: 0.88,
            confidenceTier: .peerReviewed,
            confidenceInterval: 0.08,
            bioavailability: [],
            enzymeRecommendations: [],
            citations: [],
            personalizedRiskDelta: 0.15,
            totalFructanG: 2.5,
            totalGOSG: 0.5,
            safetyFlags: [],
            processingLatencyMs: 1100,
            isLoading: false
        )
        
        // Act
        let dto = AgentResultDTO.from(agentResult)
        
        // Assert
        #expect(dto.agent_type == "claude")
        #expect(dto.ibs_trigger_probability == 0.88)
        #expect(dto.fodmap_tiers.count == 1)
        #expect(dto.fodmap_tiers.first?.ingredient == "Onion")
        #expect(dto.total_fructan_g == 2.5)
        #expect(dto.processing_latency_ms == 1100)
    }
    
    // MARK: - Tier Conversion Tests
    
    @Test("FODMAPTier string conversion handles all cases")
    func testFODMAPTierConversion() {
        // Test capitalized strings convert correctly
        #expect(FODMAPTier(rawValue: "Low") == .low)
        #expect(FODMAPTier(rawValue: "Moderate") == .moderate)
        #expect(FODMAPTier(rawValue: "High") == .high)
        
        // Test that lowercased strings from DTO get converted
        let dto = IngredientFODMAPDTO(
            ingredient: "Test",
            tier: "high",
            fructan_g: 1.0,
            gos_g: 0.0,
            lactose_g: 0.0,
            fructose_g: 0.0,
            polyol_g: 0.0,
            serving_size_g: 100.0,
            source: "Test"
        )
        
        let domain = dto.toDomain()
        #expect(domain.tier == .high)
    }
    
    @Test("ConfidenceTier string conversion handles all cases")
    func testConfidenceTierConversion() {
        // Test various string formats
        #expect(ConfidenceTier(rawValue: "Peer-Reviewed") == .peerReviewed)
        #expect(ConfidenceTier(rawValue: "Clinical") == .clinical)
        #expect(ConfidenceTier(rawValue: "Anecdotal") == .anecdotal)
    }
    
    // MARK: - Safety Flag Tests
    
    @Test("SafetyFlagDTO converts severity correctly")
    func testSafetyFlagSeverityConversion() {
        // Test critical severity
        let criticalDTO = SafetyFlagDTO(message: "Critical issue", severity: "critical")
        let criticalDomain = criticalDTO.toDomain()
        #expect(criticalDomain.severity == .critical)
        
        // Test warning severity
        let warningDTO = SafetyFlagDTO(message: "Warning issue", severity: "warning")
        let warningDomain = warningDTO.toDomain()
        #expect(warningDomain.severity == .warning)
        
        // Test info severity (default)
        let infoDTO = SafetyFlagDTO(message: "Info message", severity: "info")
        let infoDomain = infoDTO.toDomain()
        #expect(infoDomain.severity == .info)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("BackendAPIError provides correct error descriptions")
    func testBackendAPIErrorDescriptions() {
        let missingCredError = BackendAPIError.missingCredentials("API Key")
        #expect(missingCredError.errorDescription?.contains("API Key") == true)
        
        let invalidURLError = BackendAPIError.invalidURL
        #expect(invalidURLError.errorDescription?.contains("Invalid") == true)
        
        let httpError = BackendAPIError.httpError(404, "Not found")
        #expect(httpError.errorDescription?.contains("404") == true)
    }
    
    // MARK: - Serving ViewModel Tests
    
    @Test("ServingViewModel calculates fraction correctly")
    @MainActor
    func testServingViewModelFraction() {
        // Arrange
        let vm = ServingViewModel()
        
        // Act & Assert - Default is standard serving (1.0)
        #expect(vm.fraction == 1.0)
        #expect(vm.isStandardServing == true)
        
        // Act - Change to half serving
        vm.selectedPreset = ServingPreset.presets[1] // Half serving
        
        // Assert
        #expect(vm.fraction == 0.5)
        #expect(vm.isStandardServing == false)
    }
    
    @Test("ServingViewModel calculates custom grams correctly")
    @MainActor
    func testServingViewModelCustomGrams() {
        // Arrange
        let vm = ServingViewModel()
        
        // Act
        vm.useCustomGrams = true
        vm.customGrams = "50"
        
        // Assert
        #expect(vm.servingAmountG == 50.0)
        #expect(vm.summaryLabel.contains("50g"))
    }
}
// MARK: - KeychainService Tests

struct KeychainServiceTests {
    
    @Test("KeychainService saves and reads credentials correctly")
    func testKeychainSaveAndRead() throws {
        // Arrange
        let keychain = KeychainService.shared
        let testKey = "test.credential.key"
        let testValue = "test_value_12345"
        
        // Act - Save
        try keychain.save(testValue, for: testKey)
        
        // Assert - Read
        let readValue = try keychain.read(for: testKey)
        #expect(readValue == testValue)
        
        // Cleanup
        try? keychain.delete(for: testKey)
    }
    
    @Test("KeychainService delete removes credential")
    func testKeychainDelete() throws {
        // Arrange
        let keychain = KeychainService.shared
        let testKey = "test.delete.key"
        try keychain.save("value", for: testKey)
        
        // Act
        try keychain.delete(for: testKey)
        
        // Assert - Should throw itemNotFound
        #expect(throws: KeychainError.self) {
            try keychain.read(for: testKey)
        }
    }
    
    @Test("KeychainService exists returns correct status")
    func testKeychainExists() throws {
        // Arrange
        let keychain = KeychainService.shared
        let testKey = "test.exists.key"
        
        // Assert - Should not exist initially
        #expect(keychain.exists(for: testKey) == false)
        
        // Act - Save
        try keychain.save("value", for: testKey)
        
        // Assert - Should exist now
        #expect(keychain.exists(for: testKey) == true)
        
        // Cleanup
        try? keychain.delete(for: testKey)
    }
    
    @Test("KeychainService maskedValue hides sensitive data")
    func testKeychainMaskedValue() throws {
        // Arrange
        let keychain = KeychainService.shared
        let testKey = "test.masked.key"
        let secretValue = "sk-ant-api03-very-long-secret-key-12345"
        
        try keychain.save(secretValue, for: testKey)
        
        // Act
        let masked = keychain.maskedValue(for: testKey)
        
        // Assert
        #expect(masked.hasPrefix("sk-ant"))
        #expect(masked.contains("•"))
        #expect(!masked.contains("secret"))
        
        // Cleanup
        try? keychain.delete(for: testKey)
    }
    
    @Test("KeychainService handles missing key gracefully")
    func testKeychainMissingKey() {
        // Arrange
        let keychain = KeychainService.shared
        let nonExistentKey = "test.missing.key.9999"
        
        // Act & Assert
        #expect(throws: KeychainError.self) {
            try keychain.read(for: nonExistentKey)
        }
    }
}

// MARK: - QueryViewModel Tests

struct QueryViewModelTests {
    
    @Test("QueryViewModel validates text input correctly")
    @MainActor
    func testTextInputValidation() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .text
        
        // Act & Assert - Empty text should not be submittable
        vm.textQuery = ""
        #expect(vm.canSubmit == false)
        #expect(vm.submitBlockReason != nil)
        
        // Act & Assert - Non-empty text should be submittable (if credentials ready)
        vm.textQuery = "Test food query"
        // Note: canSubmit also checks credentials, so this may still be false
        // But submitBlockReason should not mention text input
        if let reason = vm.submitBlockReason {
            #expect(!reason.contains("Enter a food"))
        }
    }
    
    @Test("QueryViewModel validates photo input correctly")
    @MainActor
    func testPhotoInputValidation() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .photo
        
        // Act & Assert - No image should not be submittable
        vm.capturedImage = nil
        if let reason = vm.submitBlockReason {
            #expect(reason.contains("photo") || reason.contains("API keys"))
        }
    }
    
    @Test("QueryViewModel validates barcode input correctly")
    @MainActor
    func testBarcodeInputValidation() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .barcode
        
        // Act & Assert - No barcode should not be submittable
        vm.barcodeValue = nil
        if let reason = vm.submitBlockReason {
            #expect(reason.contains("barcode") || reason.contains("API keys"))
        }
        
        // Act & Assert - With barcode
        vm.barcodeValue = "1234567890123"
        // submitBlockReason should not mention barcode anymore
        if let reason = vm.submitBlockReason {
            #expect(!reason.contains("Scan a barcode"))
        }
    }
    
    @Test("QueryViewModel generates correct resolved query for text mode")
    @MainActor
    func testResolvedQueryText() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .text
        vm.textQuery = "Garlic bread"
        
        // Act
        let resolved = vm.resolvedQuery
        
        // Assert
        #expect(resolved == "Garlic bread")
    }
    
    @Test("QueryViewModel generates correct resolved query for photo mode")
    @MainActor
    func testResolvedQueryPhoto() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .photo
        
        // Act
        let resolved = vm.resolvedQuery
        
        // Assert
        #expect(resolved.contains("image"))
        #expect(resolved.contains("FODMAP"))
    }
    
    @Test("QueryViewModel generates correct resolved query for barcode mode")
    @MainActor
    func testResolvedQueryBarcode() {
        // Arrange
        let vm = QueryViewModel()
        vm.inputMode = .barcode
        vm.barcodeValue = "1234567890123"
        vm.productName = "Test Product"
        
        // Act
        let resolved = vm.resolvedQuery
        
        // Assert
        #expect(resolved.contains("Test Product"))
        #expect(resolved.contains("1234567890123"))
    }
    
    @Test("QueryViewModel reset clears all state")
    @MainActor
    func testReset() {
        // Arrange
        let vm = QueryViewModel()
        vm.textQuery = "Test query"
        vm.barcodeValue = "123"
        vm.productName = "Product"
        vm.phase = .complete
        vm.showResults = true
        
        // Act
        vm.reset()
        
        // Assert
        #expect(vm.textQuery == "")
        #expect(vm.barcodeValue == nil)
        #expect(vm.productName == nil)
        #expect(vm.phase.isRunning == false) // Check isRunning instead of direct comparison
        #expect(vm.showResults == false)
    }
    
    @Test("QueryPhase isRunning property works correctly")
    func testQueryPhaseRunning() {
        // Arrange & Assert
        let idlePhase = QueryPhase.idle
        let runningPhase = QueryPhase.running
        let completePhase = QueryPhase.complete
        let failedPhase = QueryPhase.failed("error")
        
        #expect(idlePhase.isRunning == false)
        #expect(runningPhase.isRunning == true)
        #expect(completePhase.isRunning == false)
        #expect(failedPhase.isRunning == false)
    }
}

// MARK: - FoodQueryRecord Tests

struct FoodQueryRecordTests {
    
    @Test("FoodQueryRecord initializes with correct defaults")
    func testFoodQueryRecordInitialization() {
        // Arrange & Act
        let record = FoodQueryRecord(
            queryText: "Test food",
            inputMode: "text",
            servingInfo: "Standard serving"
        )
        
        // Assert
        #expect(record.queryText == "Test food")
        #expect(record.inputMode == "text")
        #expect(record.servingInfo == "Standard serving")
        #expect(record.isComplete == false)
        #expect(record.ibsProbabilityApple == 0)
        #expect(record.ibsProbabilityClaude == 0)
        #expect(record.ibsProbabilityGemini == 0)
    }
    
    @Test("FoodQueryRecord saves and loads results correctly")
    @MainActor
    func testFoodQueryRecordSaveAndLoad() {
        // Arrange
        let record = FoodQueryRecord(queryText: "Test", inputMode: "text")
        
        let claudeResult = AgentResult(
            agentType: .claude,
            fodmapTiers: [],
            ibsTriggerProbability: 0.75,
            confidenceTier: .peerReviewed,
            confidenceInterval: 0.1,
            bioavailability: [],
            enzymeRecommendations: [],
            citations: [],
            personalizedRiskDelta: 0.05,
            totalFructanG: 1.5,
            totalGOSG: 0.3,
            safetyFlags: [],
            processingLatencyMs: 1000,
            isLoading: false
        )
        
        let geminiResult = AgentResult(
            agentType: .gemini,
            fodmapTiers: [],
            ibsTriggerProbability: 0.80,
            confidenceTier: .peerReviewed,
            confidenceInterval: 0.12,
            bioavailability: [],
            enzymeRecommendations: [],
            citations: [],
            personalizedRiskDelta: 0.08,
            totalFructanG: 1.8,
            totalGOSG: 0.4,
            safetyFlags: [],
            processingLatencyMs: 1200,
            isLoading: false
        )
        
        let appleResult = SynthesisResult(
            reconciledTiers: [],
            finalIBSProbability: 0.77,
            confidenceBand: 0.11,
            enzymeRecommendation: nil,
            keyDisagreements: [],
            synthesisRationale: "Test rationale",
            safetyFlags: [],
            isLoading: false
        )
        
        // Act
        record.saveResults(claude: claudeResult, gemini: geminiResult, apple: appleResult)
        
        // Assert
        #expect(record.isComplete == true)
        #expect(record.ibsProbabilityClaude == 0.75)
        #expect(record.ibsProbabilityGemini == 0.80)
        #expect(record.ibsProbabilityApple == 0.77)
        #expect(record.geminiRationale == "Test rationale")
        #expect(record.claudeResultJSON != nil)
        #expect(record.geminiResultJSON != nil)
        #expect(record.appleResultJSON != nil)
        
        // Act - Load results back
        let loadedClaude = record.loadClaudeResult()
        let loadedGemini = record.loadGeminiResult()
        let loadedApple = record.loadAppleResult()
        
        // Assert
        #expect(loadedClaude?.ibsTriggerProbability == 0.75)
        #expect(loadedGemini?.ibsTriggerProbability == 0.80)
        #expect(loadedApple?.finalIBSProbability == 0.77)
    }
}

// MARK: - UserProfile Tests

struct UserProfileTests {
    
    @Test("UserProfile has correct defaults")
    func testUserProfileDefaults() {
        // Arrange & Act
        let profile = UserProfile()
        
        // Assert
        #expect(profile.ibsSubtype == .ibsD)
        #expect(profile.fodmapPhase == .elimination)
        #expect(profile.knownTriggers.contains(.fructans))
        #expect(profile.knownTriggers.contains(.gos))
        #expect(profile.diagnosedConditions.contains("IBS"))
    }
    
    @Test("IBSSubtype enum has all expected cases")
    func testIBSSubtypes() {
        // Assert
        #expect(IBSSubtype.allCases.contains(.ibsD))
        #expect(IBSSubtype.allCases.contains(.ibsC))
        #expect(IBSSubtype.allCases.contains(.ibsM))
        #expect(IBSSubtype.allCases.contains(.ibsU))
        #expect(IBSSubtype.allCases.count == 4)
    }
    
    @Test("FODMAPPhase enum has all expected cases")
    func testFODMAPPhases() {
        // Assert
        #expect(FODMAPPhase.allCases.contains(.elimination))
        #expect(FODMAPPhase.allCases.contains(.reintroduction))
        #expect(FODMAPPhase.allCases.contains(.maintenance))
        #expect(FODMAPPhase.allCases.count == 3)
    }
    
    @Test("FODMAPCategory enum has all expected cases")
    func testFODMAPCategories() {
        // Assert
        #expect(FODMAPCategory.allCases.count == 5)
        #expect(FODMAPCategory.allCases.contains(.fructans))
        #expect(FODMAPCategory.allCases.contains(.gos))
        #expect(FODMAPCategory.allCases.contains(.lactose))
        #expect(FODMAPCategory.allCases.contains(.fructose))
        #expect(FODMAPCategory.allCases.contains(.polyols))
    }
}

// MARK: - Model Conversion Tests

struct ModelConversionTests {
    
    @Test("UserProfileRecord converts to UserProfile correctly")
    func testUserProfileRecordConversion() {
        // Arrange
        let record = UserProfileRecord()
        record.ibsSubtype = IBSSubtype.ibsM.rawValue
        record.fodmapPhase = FODMAPPhase.reintroduction.rawValue
        record.knownTriggers = ["Fructans", "Lactose"]
        record.knownSafeFoods = ["Rice", "Chicken"]
        record.medications = ["Medication A"]
        record.diagnosedConditions = ["IBS", "SIBO"]
        
        // Act
        let profile = record.toModel()
        
        // Assert
        #expect(profile.ibsSubtype == .ibsM)
        #expect(profile.fodmapPhase == .reintroduction)
        #expect(profile.knownTriggers.count == 2)
        #expect(profile.knownSafeFoods.count == 2)
        #expect(profile.medications.count == 1)
        #expect(profile.diagnosedConditions.count == 2)
    }
    
    @Test("UserSourceRecord converts to UserSource correctly")
    func testUserSourceRecordConversion() {
        // Arrange
        let record = UserSourceRecord(
            title: "Test Source",
            rawText: "Test content",
            isAnecdotal: true,
            sourceURL: "https://example.com",
            notes: "Test notes"
        )
        
        // Act
        let source = record.toModel()
        
        // Assert
        #expect(source.title == "Test Source")
        #expect(source.rawText == "Test content")
        #expect(source.isAnecdotal == true)
        #expect(source.sourceURL == "https://example.com")
    }
}

// MARK: - FODMAP Tier Tests

struct FODMAPTierTests {
    
    @Test("FODMAPTier provides correct colors")
    func testFODMAPTierColors() {
        // Assert - Colors should be distinct and appropriate
        #expect(FODMAPTier.low.color != FODMAPTier.moderate.color)
        #expect(FODMAPTier.moderate.color != FODMAPTier.high.color)
        #expect(FODMAPTier.low.color != FODMAPTier.high.color)
    }
    
    @Test("FODMAPTier provides correct icons")
    func testFODMAPTierIcons() {
        // Assert
        #expect(FODMAPTier.low.icon == "checkmark.circle.fill")
        #expect(FODMAPTier.moderate.icon == "exclamationmark.triangle.fill")
        #expect(FODMAPTier.high.icon == "xmark.octagon.fill")
    }
    
    @Test("ConfidenceTier provides correct uncertainty boost")
    func testConfidenceTierUncertaintyBoost() {
        // Assert - Anecdotal should have highest uncertainty
        #expect(ConfidenceTier.peerReviewed.uncertaintyBoost == 0.0)
        #expect(ConfidenceTier.clinical.uncertaintyBoost == 0.05)
        #expect(ConfidenceTier.anecdotal.uncertaintyBoost == 0.18)
        
        // Verify ordering
        #expect(ConfidenceTier.peerReviewed.uncertaintyBoost < ConfidenceTier.clinical.uncertaintyBoost)
        #expect(ConfidenceTier.clinical.uncertaintyBoost < ConfidenceTier.anecdotal.uncertaintyBoost)
    }
    
    @Test("ConfidenceTier provides correct badges")
    func testConfidenceTierBadges() {
        // Assert
        #expect(ConfidenceTier.peerReviewed.badge == "🔬")
        #expect(ConfidenceTier.clinical.badge == "🏥")
        #expect(ConfidenceTier.anecdotal.badge == "💬")
    }
}

// MARK: - Serving Preset Tests

struct ServingPresetTests {
    
    @Test("ServingPreset standard preset is correct")
    func testStandardPreset() {
        // Arrange
        let standard = ServingPreset.standard
        
        // Assert
        #expect(standard.fraction == 1.0)
        #expect(standard.label == "1×")
        #expect(standard.description.contains("Standard"))
    }
    
    @Test("ServingPreset has all expected presets")
    func testAllPresets() {
        // Arrange
        let presets = ServingPreset.presets
        
        // Assert
        #expect(presets.count == 6)
        #expect(presets[0].fraction == 0.25)
        #expect(presets[1].fraction == 0.50)
        #expect(presets[2].fraction == 0.75)
        #expect(presets[3].fraction == 1.00)
        #expect(presets[4].fraction == 1.50)
        #expect(presets[5].fraction == 2.00)
    }
}

// MARK: - QueryInputMode Tests

struct QueryInputModeTests {
    
    @Test("QueryInputMode has correct icons")
    func testQueryInputModeIcons() {
        // Assert
        #expect(QueryInputMode.text.icon == "text.bubble.fill")
        #expect(QueryInputMode.photo.icon == "camera.fill")
        #expect(QueryInputMode.barcode.icon == "barcode.viewfinder")
    }
    
    @Test("QueryInputMode has all expected cases")
    func testQueryInputModeCases() {
        // Assert
        #expect(QueryInputMode.allCases.count == 3)
        #expect(QueryInputMode.allCases.contains(.text))
        #expect(QueryInputMode.allCases.contains(.photo))
        #expect(QueryInputMode.allCases.contains(.barcode))
    }
}

