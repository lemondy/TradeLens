//
//  AIService.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import Foundation
import CoreData

// MARK: - Result Models

struct AITradeSummaryResult {
    let rawText: String
}

// MARK: - AI Service

final class AIService: ObservableObject {
    private let client: GeminiClient
    
    init(client: GeminiClient) {
        self.client = client
    }
    
    /// 分析近期交易并生成总结
    func summarizeRecentTrades(
        trades: [Trade],
        reviews: [Review],
        days: Int = 7
    ) async throws -> AITradeSummaryResult {
        let prompt = PromptBuilder.buildRecentSummaryPrompt(
            trades: trades,
            reviews: reviews
        )
        
        let request = GeminiTradeSummaryRequest(
            model: "gemini-2.5-flash-preview-09-2025",
            contents: [
                .init(
                    role: "user",
                    parts: [.init(text: prompt)]
                )
            ]
        )
        
        let response = try await client.send(request: request)
        
        guard let text = response.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIError.emptyResponse
        }
        
        return AITradeSummaryResult(rawText: text)
    }
    
    /// 为单笔交易生成复盘草稿（P2 功能）
    func generateReviewDraft(for trade: Trade) async throws -> String {
        let prompt = PromptBuilder.buildSingleTradeDraftPrompt(trade: trade)
        
        let request = GeminiTradeSummaryRequest(
            model: "gemini-2.5-flash-preview-09-2025",
            contents: [
                .init(
                    role: "user",
                    parts: [.init(text: prompt)]
                )
            ]
        )
        
        let response = try await client.send(request: request)
        
        guard let text = response.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIError.emptyResponse
        }
        
        return text
    }
    
    /// 情绪分析（P2 功能）
    func analyzeEmotion(from reviews: [Review]) async throws -> String {
        let prompt = PromptBuilder.buildEmotionAnalysisPrompt(reviews: reviews)
        
        let request = GeminiTradeSummaryRequest(
            model: "gemini-2.5-flash-preview-09-2025",
            contents: [
                .init(
                    role: "user",
                    parts: [.init(text: prompt)]
                )
            ]
        )
        
        let response = try await client.send(request: request)
        
        guard let text = response.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIError.emptyResponse
        }
        
        return text
    }
}

