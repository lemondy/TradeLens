//
//  AIReviewView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import CoreData

struct AIReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trade.closeTime, ascending: false)],
        animation: .default)
    private var trades: FetchedResults<Trade>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Review.createdAt, ascending: false)],
        animation: .default)
    private var reviews: FetchedResults<Review>
    
    @StateObject private var aiService = AIService(
        client: GeminiClient(apiKeyProvider: {
            SecurityService.shared.getAPIKey()
        })
    )
    
    @State private var analysisRange: AnalysisRange = .days7
    @State private var isAnalyzing = false
    @State private var currentSummary: AISummary?
    @State private var errorMessage: String?
    
    enum AnalysisRange: String, CaseIterable {
        case days7 = "过去 7 天"
        case days30 = "过去 30 天"
        case last20 = "最近 20 笔"
        case last50 = "最近 50 笔"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("AI 智能复盘")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Picker("分析范围", selection: $analysisRange) {
                    ForEach(AnalysisRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Button {
                    analyze()
                } label: {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("开始分析", systemImage: "brain.head.profile")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
            }
            .padding()
            
            Divider()
            
            // 内容区
            if let summary = currentSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let overall = summary.overallPerformance, !overall.isEmpty {
                            SectionView(title: "整体表现概述", content: overall)
                        }
                        
                        if let patterns = summary.bestWorstPatterns, !patterns.isEmpty {
                            SectionView(title: "表现最佳/最差的交易类型", content: patterns)
                        }
                        
                        if let timePatterns = summary.timePatterns, !timePatterns.isEmpty {
                            SectionView(title: "时间分布与规律", content: timePatterns)
                        }
                        
                        if let suggestions = summary.strategySuggestions, !suggestions.isEmpty {
                            SectionView(title: "策略改进建议", content: suggestions, isHighlighted: true)
                        }
                        
                        if let emotion = summary.emotionNotes, !emotion.isEmpty {
                            SectionView(title: "情绪与心理分析", content: emotion)
                        }
                    }
                    .padding()
                }
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "分析失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ContentUnavailableView(
                    "开始 AI 分析",
                    systemImage: "brain.head.profile",
                    description: Text("选择分析范围后，点击「开始分析」按钮获取 AI 智能复盘建议")
                )
            }
        }
    }
    
    private func analyze() {
        isAnalyzing = true
        errorMessage = nil
        
        let targetTrades: [Trade]
        let targetReviews: [Review]
        
        switch analysisRange {
        case .days7:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            targetTrades = Array(trades.filter { ($0.closeTime ?? Date.distantPast) >= cutoff })
            targetReviews = Array(reviews.filter { ($0.createdAt ?? Date.distantPast) >= cutoff })
        case .days30:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            targetTrades = Array(trades.filter { ($0.closeTime ?? Date.distantPast) >= cutoff })
            targetReviews = Array(reviews.filter { ($0.createdAt ?? Date.distantPast) >= cutoff })
        case .last20:
            targetTrades = Array(trades.prefix(20))
            targetReviews = Array(reviews.prefix(20))
        case .last50:
            targetTrades = Array(trades.prefix(50))
            targetReviews = Array(reviews.prefix(50))
        }
        
        Task {
            do {
                let result = try await aiService.summarizeRecentTrades(
                    trades: targetTrades,
                    reviews: targetReviews,
                    days: analysisRange == .days7 ? 7 : (analysisRange == .days30 ? 30 : 0)
                )
                
                // 解析并保存结果
                let summary = AISummary(context: viewContext)
                summary.id = UUID()
                summary.createdAt = Date()
                summary.rangeDescription = analysisRange.rawValue
                summary.rawText = result.rawText
                
                // 简单解析（实际可以更智能地解析 Markdown）
                let sections = parseMarkdownSections(result.rawText)
                summary.overallPerformance = sections["整体表现概述"]
                summary.bestWorstPatterns = sections["表现最佳/最差的交易类型"]
                summary.timePatterns = sections["时间分布与规律"]
                summary.strategySuggestions = sections["策略改进建议"]
                summary.emotionNotes = sections["情绪与心理分析"]
                
                try viewContext.save()
                
                await MainActor.run {
                    currentSummary = summary
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func parseMarkdownSections(_ text: String) -> [String: String] {
        var sections: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        var currentSection: String?
        var currentContent: [String] = []
        
        for line in lines {
            if line.hasPrefix("## ") {
                if let section = currentSection {
                    sections[section] = currentContent.joined(separator: "\n")
                }
                currentSection = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentContent = []
            } else if line.hasPrefix("# ") {
                if let section = currentSection {
                    sections[section] = currentContent.joined(separator: "\n")
                }
                currentSection = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentContent = []
            } else if !line.isEmpty {
                currentContent.append(line)
            }
        }
        
        if let section = currentSection {
            sections[section] = currentContent.joined(separator: "\n")
        }
        
        return sections
    }
}

struct SectionView: View {
    let title: String
    let content: String
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .bold()
                .foregroundStyle(isHighlighted ? .blue : .primary)
            
            Text(content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    AIReviewView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

