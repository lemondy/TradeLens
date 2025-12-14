//
//  PromptBuilder.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import Foundation
import CoreData

struct PromptBuilder {
    /// 构建近期交易总结的 Prompt
    static func buildRecentSummaryPrompt(trades: [Trade], reviews: [Review]) -> String {
        // 构建交易数据 JSON
        let tradeSummaries = trades.map { trade in
            let id = trade.id?.uuidString ?? ""
            let symbol = trade.symbol ?? ""
            let side = trade.side ?? ""
            let openTime = trade.openTime?.isoString ?? ""
            let closeTime = trade.closeTime?.isoString ?? ""
            let openPrice = trade.openPrice
            let closePrice = trade.closePrice
            let leverage = trade.leverage
            let positionSize = trade.positionSize
            let pnl = trade.profitAmount
            let pnlRate = trade.profitRate
            let status = trade.status ?? ""
            
            return """
            {
              "id": "\(id)",
              "symbol": "\(symbol)",
              "side": "\(side)",
              "openTime": "\(openTime)",
              "closeTime": "\(closeTime)",
              "openPrice": \(openPrice),
              "closePrice": \(closePrice),
              "leverage": \(leverage),
              "positionSize": \(positionSize),
              "profitAmount": \(pnl),
              "profitRate": \(pnlRate),
              "status": "\(status)"
            }
            """
        }.joined(separator: ",\n")
        
        // 构建复盘数据 JSON
        let reviewSummaries = reviews.compactMap { review -> String? in
            guard let tradeId = review.trade?.id?.uuidString else { return nil }
            let content = review.contentMarkdown ?? ""
            let tags = review.tags ?? []
            let tagStr = tags.joined(separator: ", ")
            let createdAt = review.createdAt?.isoString ?? ""
            
            // 转义 JSON 特殊字符
            let escapedContent = content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            
            return """
            {
              "tradeId": "\(tradeId)",
              "tags": "\(tagStr)",
              "content": "\(escapedContent)",
              "createdAt": "\(createdAt)"
            }
            """
        }.joined(separator: ",\n")
        
        let jsonPayload = """
        {
          "trades": [
        \(tradeSummaries)
          ],
          "reviews": [
        \(reviewSummaries)
          ]
        }
        """
        
        let instructions = """
你是一名专业的合约交易教练和分析师。请根据下面提供的 JSON 数据（近期交易记录 + 对应的复盘文本），用简体中文输出一份结构化的深度分析报告。

## 输出要求

请严格按照以下 Markdown 格式输出，包含以下 5 个部分：

### 1. 整体表现概述
- 总交易笔数、盈利笔数、亏损笔数、保本笔数
- 胜率（盈利笔数 / 总笔数）
- 总盈亏金额（USDT）和平均单笔盈亏
- 简要评价整体表现

### 2. 表现最佳/最差的交易类型
- 按交易对（symbol）统计：哪些交易对表现最好/最差
- 按方向（side）统计：做多 vs 做空的胜率和盈亏对比
- 按杠杆（leverage）区间统计：不同杠杆水平的表现差异
- 识别出最赚钱和最亏钱的交易模式

### 3. 时间分布与规律
- 分析不同时间段的交易表现（可以按小时、日期、星期等维度）
- 找出交易者在哪些时间段表现更好/更差
- 识别交易频率的规律（是否集中在某些时段）

### 4. 策略改进建议（最重要）
这是报告的核心部分，请基于复盘内容（reviews）和交易结果，提出至少 5 条具体、可执行的改进建议。
每条建议应包含：
- **问题识别**：发现了什么问题
- **影响分析**：这个问题对交易结果的影响
- **改进措施**：具体的改进方案

例如：
- "在市场震荡期，您的执行力下降，建议下次严格按照止损位执行。"
- "您在亚洲时段的交易胜率明显高于其他时段，建议优化交易时间。"
- "您的平均盈亏比为 0.8，建议提升止盈位设置。"

### 5. 情绪与心理分析（可选）
如果复盘内容（reviews）中有足够的描述性文字，尝试识别：
- 交易时的情绪状态（焦虑、过度自信、恐惧、贪婪等）
- 是否存在报复性交易、抗单、频繁加仓等行为
- 心理偏差对交易结果的影响
- 提醒用户注意交易心理的重要性

## 注意事项
- 使用 Markdown 格式，层级清晰（使用 ## 和 ### 标题）
- 语言简洁专业，避免过度啰嗦
- 总字数控制在 800-1200 字
- 重点关注可执行的改进建议
- 如果数据不足，请说明并给出一般性建议

## 数据
下面是结构化的 JSON 数据：

\(jsonPayload)

请开始分析：
"""
        
        return instructions
    }
    
    /// 构建单笔交易复盘草稿的 Prompt（P2 功能）
    static func buildSingleTradeDraftPrompt(trade: Trade) -> String {
        let symbol = trade.symbol ?? ""
        let side = trade.side == "long" ? "做多" : "做空"
        let openTime = trade.openTime?.formatted() ?? ""
        let closeTime = trade.closeTime?.formatted() ?? ""
        let openPrice = trade.openPrice
        let closePrice = trade.closePrice
        let leverage = trade.leverage
        let positionSize = trade.positionSize
        let pnl = trade.profitAmount
        let pnlRate = trade.profitRate
        let status = trade.status == "win" ? "盈利" : (trade.status == "loss" ? "亏损" : "保本")
        
        let prompt = """
你是一名专业的交易复盘助手。请根据以下交易数据，生成一份复盘草稿，帮助用户分析这笔交易。

## 交易信息
- 交易对：\(symbol)
- 方向：\(side)
- 开仓时间：\(openTime)
- 平仓时间：\(closeTime)
- 开仓价格：\(openPrice)
- 平仓价格：\(closePrice)
- 杠杆：\(leverage)x
- 仓位大小：\(positionSize)
- 盈亏金额：\(pnl) USDT
- 盈亏率：\(String(format: "%.2f", pnlRate * 100))%
- 结果：\(status)

## 要求
请生成一份结构化的复盘草稿，包含以下部分：
1. **交易机会捕捉**：分析为什么选择这个交易机会
2. **执行情况**：评估开仓和平仓的时机是否合适
3. **心理状态**：推测交易时可能的心理状态
4. **改进措施**：基于交易结果提出改进建议

请用 Markdown 格式输出，语言简洁，为每个部分提供 2-3 个要点作为起点，用户可以在基础上补充完善。
"""
        
        return prompt
    }
    
    /// 构建情绪分析的 Prompt（P2 功能）
    static func buildEmotionAnalysisPrompt(reviews: [Review]) -> String {
        let reviewTexts = reviews.compactMap { review -> String? in
            guard let content = review.contentMarkdown, !content.isEmpty else { return nil }
            let tags = review.tags ?? []
            let tagStr = tags.isEmpty ? "" : "标签: \(tags.joined(separator: ", "))"
            return """
            ---
            复盘内容：
            \(content)
            \(tagStr)
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
你是一名交易心理分析师。请分析以下复盘文本，识别交易者的情绪状态和心理偏差。

## 复盘文本
\(reviewTexts)

## 分析要求
请识别并分析：
1. **情绪状态**：焦虑、恐惧、贪婪、过度自信、沮丧等
2. **行为模式**：是否存在报复性交易、抗单、频繁加仓、不遵守止损等
3. **心理偏差**：确认偏差、损失厌恶、锚定效应等
4. **改进建议**：针对识别出的心理问题，给出具体的心理训练建议

请用 Markdown 格式输出，语言专业但易懂。
"""
        
        return prompt
    }
}

// MARK: - Date Extensions

extension Date {
    var isoString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

