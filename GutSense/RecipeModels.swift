//
//  RecipeModels.swift
//  GutSense
//
//  Recipe URL extraction and ledger models.
//  Includes RecipeX-compatible types for cross-app sharing with Reczipes.
//

import Foundation
import CryptoKit
import SwiftData

// MARK: - API DTOs

struct RecipeImageDTO: Codable {
    let url: String
    let alt: String
    let width: Int
    let height: Int
}

struct RecipeExtractRequestDTO: Codable {
    let url: String
    let html: String?  // Client-fetched HTML to bypass bot detection
}

struct RecipeExtractResultDTO: Codable {
    let url: String
    let title: String
    let ingredients: [String]
    let images: [RecipeImageDTO]
    let page_hash: String
    let extraction_method: String
}

struct RecipeFullExtractRequestDTO: Codable {
    let url: String
    let page_hash: String
    let html: String?  // Client-fetched HTML fallback
}

struct RecipeFullExtractResultDTO: Codable {
    let title: String?
    let ingredients: [String]?
    let instructions: [String]?
    let prep_time: String?
    let cook_time: String?
    let servings: StringOrArray?

    // Handle servings being either a string or array
    enum StringOrArray: Codable {
        case string(String)
        case array([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .string(str)
            } else if let arr = try? container.decode([String].self) {
                self = .array(arr)
            } else {
                self = .string("")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let s): try container.encode(s)
            case .array(let a): try container.encode(a)
            }
        }

        var displayString: String {
            switch self {
            case .string(let s): return s
            case .array(let a): return a.first ?? ""
            }
        }
    }
}

struct RecipeSaveRequestDTO: Codable {
    let url: String
    let title: String
    let ingredients: [String]
    let images: [RecipeImageDTO]
    let instructions: [String]
    let prep_time: String?
    let cook_time: String?
    let servings: String?
    let page_hash: String
}

struct RecipeSaveResponseDTO: Codable {
    let status: String
    let id: String
}

struct SavedRecipeDTO: Codable {
    let id: String
    let url: String
    let title: String
    let ingredients: [String]
    let images: [RecipeImageDTO]
    let instructions: [String]
    let prep_time: String?
    let cook_time: String?
    let servings: String?
    let saved_at: String
    let page_hash: String
}

struct RecipeListResponseDTO: Codable {
    let recipes: [SavedRecipeDTO]
}

// MARK: - Domain Models

struct RecipeImage: Identifiable {
    let id = UUID()
    let url: String
    let alt: String
    let width: Int
    let height: Int
}

struct RecipeExtractResult {
    let url: String
    let title: String
    let ingredients: [String]
    let images: [RecipeImage]
    let pageHash: String
    let extractionMethod: String
}

struct RecipeFullDetails {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let prepTime: String?
    let cookTime: String?
    let servings: String?
}

struct SavedRecipe: Identifiable {
    let id: String
    let url: String
    let title: String
    let ingredients: [String]
    let images: [RecipeImage]
    let instructions: [String]
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let savedAt: Date
    let pageHash: String
}

// MARK: - DTO → Domain

extension RecipeExtractResultDTO {
    func toDomain() -> RecipeExtractResult {
        RecipeExtractResult(
            url: url,
            title: title,
            ingredients: ingredients,
            images: images.map { RecipeImage(url: $0.url, alt: $0.alt, width: $0.width, height: $0.height) },
            pageHash: page_hash,
            extractionMethod: extraction_method
        )
    }
}

extension RecipeFullExtractResultDTO {
    func toDomain() -> RecipeFullDetails {
        RecipeFullDetails(
            title: title ?? "",
            ingredients: ingredients ?? [],
            instructions: instructions ?? [],
            prepTime: prep_time,
            cookTime: cook_time,
            servings: servings?.displayString
        )
    }
}

extension SavedRecipeDTO {
    func toDomain() -> SavedRecipe {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: saved_at) ?? Date()
        return SavedRecipe(
            id: id,
            url: url,
            title: title,
            ingredients: ingredients,
            images: images.map { RecipeImage(url: $0.url, alt: $0.alt, width: $0.width, height: $0.height) },
            instructions: instructions,
            prepTime: prep_time,
            cookTime: cook_time,
            servings: servings,
            savedAt: date,
            pageHash: page_hash
        )
    }
}

// MARK: - RecipeX-Compatible Types (shared with Reczipes)
//
// These types mirror RecipeX's structured ingredient/instruction model
// so recipes can be round-tripped between GutSense and Reczipes.

/// A single ingredient with structured quantity, unit, and name.
/// Matches RecipeX's `Ingredient` type.
struct RecipeXIngredient: Codable, Identifiable {
    var id: UUID = UUID()
    var quantity: String?
    var unit: String?
    var name: String

    enum CodingKeys: String, CodingKey {
        case quantity, unit, name
    }

    /// Parse a flat ingredient string like "2 cups flour" into structured form.
    static func parse(_ raw: String) -> RecipeXIngredient {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try to extract leading quantity and unit
        let pattern = #"^([\d¼½¾⅓⅔⅛⅜⅝⅞/.\- ]+)\s*(cups?|tbsps?|tsps?|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|g|grams?|kg|ml|liters?|litres?|pinch|dash|cloves?|cans?|packages?|slices?|pieces?|stalks?|bunche?s?|heads?|sprigs?|inches?|cm)?\s+(.+)$"#
        if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let qty = match.range(at: 1).location != NSNotFound
                ? String(trimmed[Range(match.range(at: 1), in: trimmed)!]).trimmingCharacters(in: .whitespaces)
                : nil
            let unit = match.range(at: 2).location != NSNotFound
                ? String(trimmed[Range(match.range(at: 2), in: trimmed)!])
                : nil
            let name = String(trimmed[Range(match.range(at: 3), in: trimmed)!])
            return RecipeXIngredient(quantity: qty, unit: unit, name: name)
        }
        // Fallback: entire string is the name
        return RecipeXIngredient(quantity: nil, unit: nil, name: trimmed)
    }

    /// Flatten back to display string
    var displayString: String {
        var parts: [String] = []
        if let q = quantity?.trimmingCharacters(in: .whitespaces), !q.isEmpty { parts.append(q) }
        if let u = unit?.trimmingCharacters(in: .whitespaces), !u.isEmpty { parts.append(u) }
        parts.append(name)
        return parts.joined(separator: " ")
    }
}

/// A named section of ingredients (e.g. "For the Dough", "For the Sauce").
/// Matches RecipeX's `IngredientSection` type.
struct RecipeXIngredientSection: Codable {
    var title: String
    var ingredients: [RecipeXIngredient]
}

/// A single instruction step. Matches RecipeX's `InstructionStep` type.
struct RecipeXInstructionStep: Codable {
    var stepNumber: Int
    var text: String
}

/// A named section of instruction steps.
/// Matches RecipeX's `InstructionSection` type.
struct RecipeXInstructionSection: Codable {
    var title: String
    var steps: [RecipeXInstructionStep]
}

/// Note types matching RecipeX's `RecipeNote`.
enum RecipeXNoteType: String, Codable {
    case tip, warning, substitution, variation, general
}

struct RecipeXNote: Codable {
    var type: RecipeXNoteType
    var text: String
}

// MARK: - RecipeX Export Envelope
//
// A Codable envelope that can be written to disk or shared via CloudKit
// and read by any app using the RecipeX model.

struct RecipeXEnvelope: Codable, Identifiable {
    var id: UUID
    var title: String
    var headerNotes: String?
    var recipeYield: String?
    var reference: String?

    var ingredientSections: [RecipeXIngredientSection]
    var instructionSections: [RecipeXInstructionSection]
    var notes: [RecipeXNote]

    // Image URLs (GutSense stores URLs; Reczipes stores Data — this bridges both)
    var imageURLs: [String]

    // Timestamps
    var dateAdded: Date
    var dateCreated: Date
    var lastModified: Date

    // Versioning
    var version: Int
    var ingredientsHash: String?
    var contentFingerprint: String?

    // Metadata
    var extractionSource: String?
    var cuisine: String?
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var pageHash: String?

    /// Generate SHA256 content fingerprint for duplicate detection.
    func generateContentFingerprint() -> String {
        var components: [String] = []
        components.append(title.lowercased().trimmingCharacters(in: .whitespaces))
        if let hash = ingredientsHash { components.append(hash) }
        let combined = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Calculate ingredients hash from sections.
    static func calculateIngredientsHash(from sections: [RecipeXIngredientSection]) -> String {
        let strings = sections.flatMap { section in
            section.ingredients.map { i in
                "\(i.quantity ?? "")|\(i.unit ?? "")|\(i.name)"
            }
        }.sorted()
        let combined = strings.joined(separator: "||")
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - SavedRecipe ↔ RecipeX Conversion

extension SavedRecipe {

    /// Convert to a RecipeX-compatible envelope for sharing with Reczipes.
    func toRecipeXEnvelope() -> RecipeXEnvelope {
        // Parse flat ingredient strings into structured sections
        let parsedIngredients = ingredients.map { RecipeXIngredient.parse($0) }
        let ingredientSections = [RecipeXIngredientSection(title: "Ingredients", ingredients: parsedIngredients)]

        // Convert flat instruction strings into numbered steps
        let steps = instructions.enumerated().map { RecipeXInstructionStep(stepNumber: $0.offset + 1, text: $0.element) }
        let instructionSections = [RecipeXInstructionSection(title: "Instructions", steps: steps)]

        let envID = UUID(uuidString: id) ?? UUID()
        let imageURLs = images.map(\.url)

        // Parse time strings to minutes
        let prepMinutes = Self.parseTimeToMinutes(prepTime)
        let cookMinutes = Self.parseTimeToMinutes(cookTime)

        var envelope = RecipeXEnvelope(
            id: envID,
            title: title,
            headerNotes: nil,
            recipeYield: servings,
            reference: url,
            ingredientSections: ingredientSections,
            instructionSections: instructionSections,
            notes: [],
            imageURLs: imageURLs,
            dateAdded: savedAt,
            dateCreated: savedAt,
            lastModified: savedAt,
            version: 1,
            ingredientsHash: nil,
            contentFingerprint: nil,
            extractionSource: "web",
            cuisine: nil,
            prepTimeMinutes: prepMinutes,
            cookTimeMinutes: cookMinutes,
            pageHash: pageHash
        )

        envelope.ingredientsHash = RecipeXEnvelope.calculateIngredientsHash(from: ingredientSections)
        envelope.contentFingerprint = envelope.generateContentFingerprint()
        return envelope
    }

    /// Create a SavedRecipe from a RecipeX envelope (import from Reczipes).
    static func fromRecipeXEnvelope(_ env: RecipeXEnvelope) -> SavedRecipe {
        let flatIngredients = env.ingredientSections.flatMap { section in
            section.ingredients.map(\.displayString)
        }
        let flatInstructions = env.instructionSections.flatMap { section in
            section.steps.map(\.text)
        }
        let recipeImages = env.imageURLs.enumerated().map { idx, url in
            RecipeImage(url: url, alt: "Image \(idx + 1)", width: 0, height: 0)
        }

        return SavedRecipe(
            id: env.id.uuidString,
            url: env.reference ?? "",
            title: env.title,
            ingredients: flatIngredients,
            images: recipeImages,
            instructions: flatInstructions,
            prepTime: env.prepTimeMinutes.map { "\($0) minutes" },
            cookTime: env.cookTimeMinutes.map { "\($0) minutes" },
            servings: env.recipeYield,
            savedAt: env.dateAdded,
            pageHash: env.pageHash ?? ""
        )
    }

    /// Parse a time string like "30 minutes" or "1 hour 15 min" into total minutes.
    private static func parseTimeToMinutes(_ timeString: String?) -> Int? {
        guard let s = timeString?.lowercased() else { return nil }
        var total = 0
        let hourPattern = #"(\d+)\s*h"#
        let minPattern = #"(\d+)\s*m"#
        if let hMatch = try? NSRegularExpression(pattern: hourPattern).firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let range = Range(hMatch.range(at: 1), in: s) {
            total += (Int(s[range]) ?? 0) * 60
        }
        if let mMatch = try? NSRegularExpression(pattern: minPattern).firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let range = Range(mMatch.range(at: 1), in: s) {
            total += Int(s[range]) ?? 0
        }
        // If only a bare number, assume minutes
        if total == 0, let n = Int(s.trimmingCharacters(in: .letters.union(.whitespaces))) {
            total = n
        }
        return total > 0 ? total : nil
    }
}
