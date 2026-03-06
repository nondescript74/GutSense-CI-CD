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
