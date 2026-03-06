//
//  Models.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

//
//  Models.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

@preconcurrency import Foundation
import SwiftData
import SwiftUI
import CryptoKit

// MARK: - SwiftData Models

@Model
final class FoodQueryRecord: Identifiable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var queryText: String = ""
    var inputMode: String = "text"
    var servingInfo: String? = nil
    
    // Simplified result data for display
    var ibsProbabilityApple: Double = 0
    var ibsProbabilityClaude: Double = 0
    var ibsProbabilityGemini: Double = 0
    var geminiRationale: String = ""
    
    // JSON-encoded full results for viewing later
    var appleResultJSON: String? = nil
    var claudeResultJSON: String? = nil
    var geminiResultJSON: String? = nil

    init(queryText: String, inputMode: String, servingInfo: String? = nil) {
        self.queryText = queryText
        self.inputMode = inputMode
        self.servingInfo = servingInfo
        self.timestamp = Date()
    }
    
    func saveResults(claude: AgentResult, gemini: AgentResult, apple: SynthesisResult) {
        self.ibsProbabilityClaude = claude.ibsTriggerProbability
        self.ibsProbabilityGemini = gemini.ibsTriggerProbability
        self.ibsProbabilityApple = apple.finalIBSProbability
        self.geminiRationale = apple.synthesisRationale
        
        // Encode full results as JSON
        let encoder = JSONEncoder()
        let claudeDTO = AgentResultDTO.from(claude)
        let geminiDTO = AgentResultDTO.from(gemini)
        let appleDTO = SynthesisResultDTO.from(apple)
        
        MainActor.assumeIsolated {
            do {
                let appleData = try encoder.encode(appleDTO)
                self.appleResultJSON = String(data: appleData, encoding: .utf8)
            } catch {}
            
            do {
                let claudeData = try encoder.encode(claudeDTO)
                self.claudeResultJSON = String(data: claudeData, encoding: .utf8)
            } catch {}
            
            do {
                let geminiData = try encoder.encode(geminiDTO)
                self.geminiResultJSON = String(data: geminiData, encoding: .utf8)
            } catch {}
        }
    }
    
    func loadAppleResult() -> SynthesisResult? {
        guard let json = appleResultJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return MainActor.assumeIsolated {
            do {
                let dto = try JSONDecoder().decode(SynthesisResultDTO.self, from: data)
                return dto.toDomain()
            } catch {
                return nil
            }
        }
    }
    
    func loadClaudeResult() -> AgentResult? {
        guard let json = claudeResultJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return MainActor.assumeIsolated {
            do {
                let dto = try JSONDecoder().decode(AgentResultDTO.self, from: data)
                return dto.toDomain(agentType: .claude)
            } catch {
                return nil
            }
        }
    }
    
    func loadGeminiResult() -> AgentResult? {
        guard let json = geminiResultJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return MainActor.assumeIsolated {
            do {
                let dto = try JSONDecoder().decode(AgentResultDTO.self, from: data)
                return dto.toDomain(agentType: .gemini)
            } catch {
                return nil
            }
        }
    }
}

@Model
final class UserSourceRecord {
    var id: UUID = UUID()
    var title: String = ""
    var rawText: String = ""
    var isAnecdotal: Bool = false
    var sourceURL: String? = nil
    var dateAdded: Date = Date()
    var notes: String = ""

    init(title: String, rawText: String, isAnecdotal: Bool, sourceURL: String? = nil, notes: String = "") {
        self.title = title
        self.rawText = rawText
        self.isAnecdotal = isAnecdotal
        self.sourceURL = sourceURL
        self.notes = notes
    }

    func toModel() -> UserSource {
        UserSource(title: title, rawText: rawText, isAnecdotal: isAnecdotal, sourceURL: sourceURL)
    }
}

@Model
final class UserProfileRecord {
    var ibsSubtype: String = IBSSubtype.ibsD.rawValue
    var fodmapPhase: String = FODMAPPhase.elimination.rawValue
    var knownTriggers: [String] = []
    var knownSafeFoods: [String] = []
    var medications: [String] = []
    var diagnosedConditions: [String] = []

    init() {}

    func toModel() -> UserProfile {
        var p = UserProfile()
        p.ibsSubtype = IBSSubtype(rawValue: ibsSubtype) ?? .ibsD
        p.fodmapPhase = FODMAPPhase(rawValue: fodmapPhase) ?? .elimination
        p.knownTriggers = knownTriggers.compactMap { FODMAPCategory(rawValue: $0) }
        p.knownSafeFoods = knownSafeFoods
        p.medications = medications
        p.diagnosedConditions = diagnosedConditions
        return p
    }
}

// MARK: - User Profile (in-memory)

enum IBSSubtype: String, CaseIterable, Identifiable {
    case ibsD = "IBS-D"
    case ibsC = "IBS-C"
    case ibsM = "IBS-M"
    case ibsU = "IBS-U"
    var id: String { rawValue }
}

enum FODMAPPhase: String, CaseIterable, Identifiable {
    case elimination    = "Elimination"
    case reintroduction = "Reintroduction"
    case maintenance    = "Maintenance"
    var id: String { rawValue }
}

enum FODMAPCategory: String, CaseIterable, Identifiable {
    case fructans = "Fructans"
    case gos      = "GOS"
    case lactose  = "Lactose"
    case fructose = "Fructose"
    case polyols  = "Polyols"
    var id: String { rawValue }
}

struct UserProfile {
    var ibsSubtype: IBSSubtype = .ibsD
    var fodmapPhase: FODMAPPhase = .elimination
    var knownTriggers: [FODMAPCategory] = [.fructans, .gos]
    var knownSafeFoods: [String] = []
    var medications: [String] = []
    var diagnosedConditions: [String] = ["IBS"]
}

struct UserSource {
    var title: String
    var rawText: String
    var isAnecdotal: Bool
    var sourceURL: String?
}

// MARK: - FODMAP Domain Types

enum FODMAPTier: String, CaseIterable {
    case low      = "Low"
    case moderate = "Moderate"
    case high     = "High"

    var color: Color {
        switch self {
        case .low:      return Color(red: 0.18, green: 0.72, blue: 0.42)
        case .moderate: return Color(red: 0.95, green: 0.65, blue: 0.10)
        case .high:     return Color(red: 0.88, green: 0.25, blue: 0.25)
        }
    }

    var icon: String {
        switch self {
        case .low:      return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "xmark.octagon.fill"
        }
    }
}

enum AgentType: String {
    case apple      = "apple"
    case claude     = "claude"
    case gemini     = "gemini"
    case perplexity = "perplexity"
}

enum ConfidenceTier: String, CaseIterable {
    case peerReviewed = "Peer-Reviewed"
    case clinical     = "Clinical"
    case anecdotal    = "Anecdotal"

    var badge: String {
        switch self {
        case .peerReviewed: return "🔬"
        case .clinical:     return "🏥"
        case .anecdotal:    return "💬"
        }
    }

    /// Non-negotiable safety rule: anecdotal sources widen CI by ±18%
    var uncertaintyBoost: Double {
        switch self {
        case .peerReviewed: return 0.0
        case .clinical:     return 0.05
        case .anecdotal:    return 0.18
        }
    }
}

enum FlagSeverity: Equatable, Sendable {
    case info
    case warning
    case critical
}

// MARK: - Agent Data Structs

struct IngredientFODMAP: Identifiable {
    let id = UUID()
    let ingredient: String
    let tier: FODMAPTier
    let fructanG: Double?
    let gosG: Double?
    let lactoseG: Double?
    let fructoseG: Double?
    let polyolG: Double?
    let servingSizeG: Double
    let source: String
}

struct EnzymeRecommendation: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let targets: String
    let dose: String
    let temperatureWarning: Bool
    let notes: String
}

struct Citation: Identifiable {
    let id = UUID()
    let title: String
    let source: String
    let confidenceTier: ConfidenceTier
    let url: String?
}

struct BioavailabilityChange: Identifiable {
    let id = UUID()
    let nutrient: String
    let rawPercent: Double
    let cookedPercent: Double
    let note: String
}

struct SafetyFlag: Identifiable {
    let id = UUID()
    let message: String
    let severity: FlagSeverity
}

// MARK: - Agent Result

struct AgentResult {
    let agentType: AgentType
    let fodmapTiers: [IngredientFODMAP]
    let ibsTriggerProbability: Double
    let confidenceTier: ConfidenceTier
    let confidenceInterval: Double
    let bioavailability: [BioavailabilityChange]
    let enzymeRecommendations: [EnzymeRecommendation]
    let citations: [Citation]
    let personalizedRiskDelta: Double
    let totalFructanG: Double
    let totalGOSG: Double
    let safetyFlags: [SafetyFlag]
    let processingLatencyMs: Int
    let isLoading: Bool
}

// MARK: - Synthesis Result

struct SynthesisResult {
    let reconciledTiers: [IngredientFODMAP]
    let finalIBSProbability: Double
    let confidenceBand: Double
    let enzymeRecommendation: EnzymeRecommendation?
    let keyDisagreements: [String]
    let synthesisRationale: String
    let safetyFlags: [SafetyFlag]
    let isLoading: Bool
}


