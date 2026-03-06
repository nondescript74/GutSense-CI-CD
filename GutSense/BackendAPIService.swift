// GutSense — BackendAPIService.swift
// Adds serving_fraction, serving_amount_g, serving_description to every request

// GutSense — BackendAPIService.swift
// Adds serving_fraction, serving_amount_g, serving_description to every request

import Foundation
import Combine
import UIKit

// MARK: - Request DTOs

struct AnalysisRequestDTO: Codable {
    let query: String
    let user_profile: UserProfileDTO
    let user_sources: [UserSourceDTO]
    let apple_result_json: String?
    let serving_description: String?
    let serving_fraction: Double?
    let serving_amount_g: Double?
    let image_base64: String?
    let image_media_type: String?   // NOTE: was image_mime_type — renamed to match backend
}

struct UserProfileDTO: Codable {
    let ibs_subtype: String
    let fodmap_phase: String
    let known_triggers: [String]
    let known_safe_foods: [String]
    let medications: [String]
    let diagnosed_conditions: [String]
}

struct UserSourceDTO: Codable {
    let title: String
    let raw_text: String
    let is_anecdotal: Bool
    let source_url: String?
}

// MARK: - Response DTOs

@preconcurrency struct AgentResultDTO: Codable, @unchecked Sendable {
    let agent_type: String
    let fodmap_tiers: [IngredientFODMAPDTO]
    let ibs_trigger_probability: Double
    let confidence_tier: String
    let confidence_interval: Double
    let bioavailability: [BioavailabilityChangeDTO]
    let enzyme_recommendations: [EnzymeRecommendationDTO]
    let citations: [CitationDTO]
    let personalized_risk_delta: Double
    let total_fructan_g: Double
    let total_gos_g: Double
    let safety_flags: [SafetyFlagDTO]
    let processing_latency_ms: Int
}

@preconcurrency struct SynthesisResultDTO: Codable, @unchecked Sendable {
    let reconciled_tiers: [IngredientFODMAPDTO]
    let final_ibs_probability: Double
    let confidence_band: Double
    let enzyme_recommendation: EnzymeRecommendationDTO?
    let key_disagreements: [String]
    let synthesis_rationale: String
    let safety_flags: [SafetyFlagDTO]
}

struct IngredientFODMAPDTO: Codable, @unchecked Sendable {
    let ingredient: String
    let tier: String
    let fructan_g: Double?
    let gos_g: Double?
    let lactose_g: Double?
    let fructose_g: Double?
    let polyol_g: Double?
    let serving_size_g: Double
    let source: String
}

struct EnzymeRecommendationDTO: Codable, @unchecked Sendable {
    let name: String
    let brand: String
    let targets: String
    let dose: String
    let temperature_warning: Bool
    let notes: String
}

struct CitationDTO: Codable, @unchecked Sendable {
    let title: String
    let source: String
    let confidence_tier: String
    let url: String?
}

struct BioavailabilityChangeDTO: Codable, @unchecked Sendable {
    let nutrient: String
    let raw_percent: Double
    let cooked_percent: Double
    let note: String
}

struct SafetyFlagDTO: Codable, @unchecked Sendable {
    let message: String
    let severity: String
}

// MARK: - Error

enum BackendAPIError: LocalizedError {
    case missingCredentials(String)
    case invalidURL
    case networkError(Error)
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let f): return "Missing credential: \(f). Go to Settings → API Keys."
        case .invalidURL:               return "Invalid backend URL. Check Settings → API Keys."
        case .networkError(let e):      return "Network error: \(e.localizedDescription)"
        case .httpError(let c, let m):  return "Backend error \(c): \(m)"
        case .decodingError(let e):     return "Could not parse response: \(e.localizedDescription)"
        }
    }
}

// MARK: - DTO → Domain

extension AgentResultDTO {
    nonisolated func toDomain(agentType: AgentType) -> AgentResult {
        AgentResult(
            agentType: agentType,
            fodmapTiers: fodmap_tiers.map { $0.toDomain() },
            ibsTriggerProbability: ibs_trigger_probability,
            confidenceTier: ConfidenceTier(rawValue: confidence_tier.capitalized
                .replacingOccurrences(of: "-", with: " ")) ?? .peerReviewed,
            confidenceInterval: confidence_interval,
            bioavailability: bioavailability.map { $0.toDomain() },
            enzymeRecommendations: enzyme_recommendations.map { $0.toDomain() },
            citations: citations.map { $0.toDomain() },
            personalizedRiskDelta: personalized_risk_delta,
            totalFructanG: total_fructan_g,
            totalGOSG: total_gos_g,
            safetyFlags: safety_flags.map { $0.toDomain() },
            processingLatencyMs: processing_latency_ms,
            isLoading: false
        )
    }
}

extension SynthesisResultDTO {
    nonisolated func toDomain() -> SynthesisResult {
        SynthesisResult(
            reconciledTiers: reconciled_tiers.map { $0.toDomain() },
            finalIBSProbability: final_ibs_probability,
            confidenceBand: confidence_band,
            enzymeRecommendation: enzyme_recommendation?.toDomain(),
            keyDisagreements: key_disagreements,
            synthesisRationale: synthesis_rationale,
            safetyFlags: safety_flags.map { $0.toDomain() },
            isLoading: false
        )
    }
}

extension IngredientFODMAPDTO {
    nonisolated func toDomain() -> IngredientFODMAP {
        IngredientFODMAP(
            ingredient: ingredient,
            tier: FODMAPTier(rawValue: tier.capitalized) ?? .moderate,
            fructanG: fructan_g, gosG: gos_g, lactoseG: lactose_g,
            fructoseG: fructose_g, polyolG: polyol_g,
            servingSizeG: serving_size_g, source: source
        )
    }
}

extension EnzymeRecommendationDTO {
    nonisolated func toDomain() -> EnzymeRecommendation {
        EnzymeRecommendation(name: name, brand: brand, targets: targets,
                             dose: dose, temperatureWarning: temperature_warning, notes: notes)
    }
}

extension CitationDTO {
    nonisolated func toDomain() -> Citation {
        Citation(title: title, source: source,
                 confidenceTier: ConfidenceTier(rawValue: confidence_tier.capitalized
                     .replacingOccurrences(of: "-", with: " ")) ?? .peerReviewed,
                 url: url)
    }
}

extension BioavailabilityChangeDTO {
    nonisolated func toDomain() -> BioavailabilityChange {
        BioavailabilityChange(nutrient: nutrient, rawPercent: raw_percent,
                              cookedPercent: cooked_percent, note: note)
    }
}

extension SafetyFlagDTO {
    nonisolated func toDomain() -> SafetyFlag {
        let sev: FlagSeverity = severity == "critical" ? .critical
                              : severity == "warning"  ? .warning : .info
        return SafetyFlag(message: message, severity: sev)
    }
}

// MARK: - Service

@MainActor
final class BackendAPIService: ObservableObject {
    static let shared = BackendAPIService()
    private let keychain = KeychainService.shared

    private var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest  = 120  // Increased to 2 minutes for synthesis
        c.timeoutIntervalForResource = 180  // Increased to 3 minutes for synthesis
        return URLSession(configuration: c)
    }()
    private init() {}

    func healthCheck() async -> Bool {
        guard let base = keychain.read(forKey: "gutsense.backend_url"),
              let url = URL(string: "\(base)/health") else { return false }
        return (try? await session.data(from: url))
            .map { (_, r) in (r as? HTTPURLResponse)?.statusCode == 200 } ?? false
    }

    func analyzeClaude(query: String, profile: UserProfile,
                       sources: [UserSource] = [],
                       serving: ServingViewModel? = nil,
                       image: UIImage? = nil) async throws -> AgentResult {
        let dto = makeDTO(query: query, profile: profile, sources: sources,
                          appleJSON: nil, serving: serving, image: image)
        let r: AgentResultDTO = try await post(path: "/analyze/claude", body: dto)
        return r.toDomain(agentType: .claude)
    }

    func analyzeGemini(query: String, profile: UserProfile,
                       sources: [UserSource] = [],
                       serving: ServingViewModel? = nil,
                       image: UIImage? = nil) async throws -> AgentResult {
        let dto = makeDTO(query: query, profile: profile, sources: sources,
                          appleJSON: nil, serving: serving, image: image)
        let r: AgentResultDTO = try await post(path: "/analyze/gemini", body: dto)
        return r.toDomain(agentType: .gemini)
    }

    func synthesizeGemini(query: String, profile: UserProfile,
                          sources: [UserSource] = [],
                          appleResultJSON: String,
                          serving: ServingViewModel? = nil,
                          image: UIImage? = nil) async throws -> SynthesisResult {
        let dto = makeDTO(query: query, profile: profile, sources: sources,
                          appleJSON: appleResultJSON, serving: serving, image: image)
        
        // Retry up to 2 times on timeout errors
        var lastError: Error?
        for attempt in 1...2 {
            do {
                let r: SynthesisResultDTO = try await post(path: "/analyze/gemini", body: dto)
                return r.toDomain()
            } catch let error as BackendAPIError {
                lastError = error
                // Only retry on network errors (which includes timeouts)
                if case .networkError = error, attempt < 2 {
                    print("Gemini synthesis attempt \(attempt) failed with timeout, retrying...")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds before retry
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }
        
        throw lastError ?? BackendAPIError.networkError(NSError(domain: "GutSense", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }

    // MARK: - Generic POST

    private func post<Req: Encodable, Res: Decodable>(path: String, body: Req) async throws -> Res {
        guard let base = keychain.read(forKey: "gutsense.backend_url") else {
            throw BackendAPIError.missingCredentials("GutSense Backend URL")
        }
        let clean = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: clean + path) else { throw BackendAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret = keychain.read(forKey: "gutsense.api_secret") {
            req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        do { req.httpBody = try JSONEncoder().encode(body) }
        catch { throw BackendAPIError.decodingError(error) }

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw BackendAPIError.networkError(error) }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw BackendAPIError.httpError(http.statusCode,
                String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        do { return try JSONDecoder().decode(Res.self, from: data) }
        catch { throw BackendAPIError.decodingError(error) }
    }

    // MARK: - DTO Builder

    private func makeDTO(query: String, profile: UserProfile, sources: [UserSource],
                         appleJSON: String?, serving: ServingViewModel?,
                         image: UIImage? = nil) -> AnalysisRequestDTO {

        var imageBase64: String? = nil
        var imageMediaType: String? = nil

        if let image = image {
            let resized = resizeImage(image, maxDimension: 1024)
            if let jpegData = resized.jpegData(compressionQuality: 0.8) {
                imageBase64 = jpegData.base64EncodedString()
                imageMediaType = "image/jpeg"
            }
        }

        return AnalysisRequestDTO(
            query: query,
            user_profile: UserProfileDTO(
                ibs_subtype: profile.ibsSubtype.rawValue,
                fodmap_phase: profile.fodmapPhase.rawValue,
                known_triggers: profile.knownTriggers.map { $0.rawValue },
                known_safe_foods: profile.knownSafeFoods,
                medications: profile.medications,
                diagnosed_conditions: profile.diagnosedConditions
            ),
            user_sources: sources.map {
                UserSourceDTO(title: $0.title, raw_text: $0.rawText,
                              is_anecdotal: $0.isAnecdotal, source_url: $0.sourceURL)
            },
            apple_result_json: appleJSON,
            serving_description: serving?.servingDescription.isEmpty == false
                ? serving?.servingDescription : nil,
            serving_fraction: (serving?.isStandardServing == false && serving?.useCustomGrams == false)
                ? serving?.fraction : nil,
            serving_amount_g: serving?.servingAmountG,
            image_base64: imageBase64,
            image_media_type: imageMediaType
        )
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let aspectRatio = size.width / size.height
        let newSize: CGSize = size.width > size.height
            ? CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            : CGSize(width: maxDimension * aspectRatio, height: maxDimension)

        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - KeychainService convenience

extension KeychainService {
    func read(forKey key: String) -> String? { try? read(for: key) }
}

// MARK: - Domain → DTO (for saving to SwiftData)

extension AgentResultDTO {
    nonisolated static func from(_ result: AgentResult) -> AgentResultDTO {
        AgentResultDTO(
            agent_type: result.agentType.rawValue,
            fodmap_tiers: result.fodmapTiers.map { IngredientFODMAPDTO.from($0) },
            ibs_trigger_probability: result.ibsTriggerProbability,
            confidence_tier: result.confidenceTier.rawValue.lowercased()
                .replacingOccurrences(of: " ", with: "-"),
            confidence_interval: result.confidenceInterval,
            bioavailability: result.bioavailability.map { BioavailabilityChangeDTO.from($0) },
            enzyme_recommendations: result.enzymeRecommendations.map { EnzymeRecommendationDTO.from($0) },
            citations: result.citations.map { CitationDTO.from($0) },
            personalized_risk_delta: result.personalizedRiskDelta,
            total_fructan_g: result.totalFructanG,
            total_gos_g: result.totalGOSG,
            safety_flags: result.safetyFlags.map { SafetyFlagDTO.from($0) },
            processing_latency_ms: result.processingLatencyMs
        )
    }
}

extension SynthesisResultDTO {
    nonisolated static func from(_ result: SynthesisResult) -> SynthesisResultDTO {
        SynthesisResultDTO(
            reconciled_tiers: result.reconciledTiers.map { IngredientFODMAPDTO.from($0) },
            final_ibs_probability: result.finalIBSProbability,
            confidence_band: result.confidenceBand,
            enzyme_recommendation: result.enzymeRecommendation.map { EnzymeRecommendationDTO.from($0) },
            key_disagreements: result.keyDisagreements,
            synthesis_rationale: result.synthesisRationale,
            safety_flags: result.safetyFlags.map { SafetyFlagDTO.from($0) }
        )
    }
}

extension IngredientFODMAPDTO {
    nonisolated static func from(_ item: IngredientFODMAP) -> IngredientFODMAPDTO {
        IngredientFODMAPDTO(
            ingredient: item.ingredient,
            tier: item.tier.rawValue.lowercased(),
            fructan_g: item.fructanG,
            gos_g: item.gosG,
            lactose_g: item.lactoseG,
            fructose_g: item.fructoseG,
            polyol_g: item.polyolG,
            serving_size_g: item.servingSizeG,
            source: item.source
        )
    }
}

extension EnzymeRecommendationDTO {
    nonisolated static func from(_ enzyme: EnzymeRecommendation) -> EnzymeRecommendationDTO {
        EnzymeRecommendationDTO(
            name: enzyme.name,
            brand: enzyme.brand,
            targets: enzyme.targets,
            dose: enzyme.dose,
            temperature_warning: enzyme.temperatureWarning,
            notes: enzyme.notes
        )
    }
}

extension CitationDTO {
    nonisolated static func from(_ citation: Citation) -> CitationDTO {
        CitationDTO(
            title: citation.title,
            source: citation.source,
            confidence_tier: citation.confidenceTier.rawValue.lowercased()
                .replacingOccurrences(of: " ", with: "-"),
            url: citation.url
        )
    }
}

extension BioavailabilityChangeDTO {
    nonisolated static func from(_ change: BioavailabilityChange) -> BioavailabilityChangeDTO {
        BioavailabilityChangeDTO(
            nutrient: change.nutrient,
            raw_percent: change.rawPercent,
            cooked_percent: change.cookedPercent,
            note: change.note
        )
    }
}

extension SafetyFlagDTO {
    nonisolated static func from(_ flag: SafetyFlag) -> SafetyFlagDTO {
        let severity: String = {
            switch flag.severity {
            case .critical: return "critical"
            case .warning:  return "warning"
            case .info:     return "info"
            }
        }()
        return SafetyFlagDTO(message: flag.message, severity: severity)
    }
}
