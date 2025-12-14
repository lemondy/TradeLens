//
//  OCRService.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import Foundation
import Vision
import AppKit

struct TradeData {
    var symbol: String = ""
    var side: String = "long" // "long" or "short"
    var openTime: Date?
    var closeTime: Date?
    var openPrice: Double = 0
    var closePrice: Double = 0
    var leverage: Int = 10
    var positionSize: Double = 0
    var profitAmount: Double = 0
    var profitRate: Double = 0
}

final class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// 从图片中识别文本
    func recognizeText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            // 支持中英文识别
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 从 OCR 文本中解析交易数据
    func parseTradeData(from text: String) -> TradeData? {
        var tradeData = TradeData()
        
        let lines = text.components(separatedBy: .newlines)
        let fullText = text.replacingOccurrences(of: "\n", with: " ")
        
        // 1. 解析交易对（例如：ZECUSDT、FHEUSDT、1000LUNCUSDT）
        if let symbolMatch = extractSymbol(from: fullText) {
            tradeData.symbol = symbolMatch
        }
        
        // 2. 解析方向（做多/做空）
        if fullText.contains("做多") || fullText.contains("Long") || fullText.contains("long") {
            tradeData.side = "long"
        } else if fullText.contains("做空") || fullText.contains("Short") || fullText.contains("short") {
            tradeData.side = "short"
        }
        
        // 3. 解析开仓时间
        if let openTime = extractDate(from: fullText, keywords: ["开仓时间", "Open Time", "开仓"]) {
            tradeData.openTime = openTime
        }
        
        // 4. 解析平仓时间
        if let closeTime = extractDate(from: fullText, keywords: ["平仓时间", "Close Time", "平仓", "Average Close"]) {
            tradeData.closeTime = closeTime
        }
        
        // 5. 解析开仓价格
        if let openPrice = extractPrice(from: fullText, keywords: ["开仓价格", "Open Price", "开仓"]) {
            tradeData.openPrice = openPrice
        }
        
        // 6. 解析平仓价格
        if let closePrice = extractPrice(from: fullText, keywords: ["平仓价格", "Close Price", "Average Close Price", "平仓"]) {
            tradeData.closePrice = closePrice
        }
        
        // 7. 解析杠杆（如果有）
        if let leverage = extractLeverage(from: fullText) {
            tradeData.leverage = leverage
        }
        
        // 8. 解析仓位大小
        if let positionSize = extractPositionSize(from: fullText) {
            tradeData.positionSize = positionSize
        }
        
        // 9. 解析盈亏金额
        if let profitAmount = extractProfitAmount(from: fullText) {
            tradeData.profitAmount = profitAmount
        }
        
        // 10. 解析盈亏率
        if let profitRate = extractProfitRate(from: fullText) {
            tradeData.profitRate = profitRate
        }
        
        // 验证必要字段
        guard !tradeData.symbol.isEmpty,
              tradeData.openPrice > 0,
              tradeData.closePrice > 0 else {
            return nil
        }
        
        return tradeData
    }
    
    // MARK: - 辅助解析方法
    
    private func extractSymbol(from text: String) -> String? {
        // 匹配交易对模式：字母+数字+USDT（例如：ZECUSDT, FHEUSDT, 1000LUNCUSDT）
        let patterns = [
            #"([A-Z0-9]+USDT)"#,
            #"([A-Z0-9]+USDT\s*永续)"#,
            #"([A-Z0-9]+USDT\s*Perpetual)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let symbol = String(text[range])
                return symbol.replacingOccurrences(of: "永续", with: "")
                             .replacingOccurrences(of: "Perpetual", with: "")
                             .trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
    
    private func extractDate(from text: String, keywords: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        // 尝试多种日期格式
        let formats = [
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss",
            "MM-dd-yyyy HH:mm:ss",
            "yyyy/MM/dd",
            "yyyy-MM-dd"
        ]
        
        for keyword in keywords {
            if let range = text.range(of: keyword, options: .caseInsensitive) {
                let afterKeyword = String(text[range.upperBound...])
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: afterKeyword.trimmingCharacters(in: .whitespaces).prefix(19)) {
                        return date
                    }
                }
                
                // 尝试提取日期部分
                let datePattern = #"(\d{4}[-/]\d{1,2}[-/]\d{1,2}[\s\d:]*)"#
                if let regex = try? NSRegularExpression(pattern: datePattern),
                   let match = regex.firstMatch(in: afterKeyword, range: NSRange(afterKeyword.startIndex..., in: afterKeyword)),
                   let matchRange = Range(match.range, in: afterKeyword) {
                    let dateString = String(afterKeyword[matchRange])
                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractPrice(from text: String, keywords: [String]) -> Double? {
        for keyword in keywords {
            if let range = text.range(of: keyword, options: .caseInsensitive) {
                let afterKeyword = String(text[range.upperBound...])
                
                // 匹配价格模式：数字（可能包含小数点）
                let pricePattern = #"(\d+\.?\d*)\s*USDT"#
                if let regex = try? NSRegularExpression(pattern: pricePattern),
                   let match = regex.firstMatch(in: afterKeyword, range: NSRange(afterKeyword.startIndex..., in: afterKeyword)),
                   let matchRange = Range(match.range(at: 1), in: afterKeyword) {
                    return Double(String(afterKeyword[matchRange]))
                }
                
                // 如果没有 USDT，尝试直接提取数字
                let numberPattern = #"(\d+\.?\d{2,8})"#
                if let regex = try? NSRegularExpression(pattern: numberPattern),
                   let match = regex.firstMatch(in: afterKeyword, range: NSRange(afterKeyword.startIndex..., in: afterKeyword)),
                   let matchRange = Range(match.range(at: 1), in: afterKeyword) {
                    return Double(String(afterKeyword[matchRange]))
                }
            }
        }
        
        return nil
    }
    
    private func extractLeverage(from text: String) -> Int? {
        let patterns = [
            #"杠杆[：:]\s*(\d+)"#,
            #"Leverage[：:]\s*(\d+)"#,
            #"(\d+)x"#,
            #"(\d+)X"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(String(text[range]))
            }
        }
        
        return nil
    }
    
    private func extractPositionSize(from text: String) -> Double? {
        let patterns = [
            #"仓位[大小]*[：:]\s*(\d+\.?\d*)"#,
            #"Position[：:]\s*(\d+\.?\d*)"#,
            #"Closed Quantity[：:]\s*(\d+\.?\d*)"#,
            #"最大持仓[：:]\s*(\d+\.?\d*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Double(String(text[range]))
            }
        }
        
        return nil
    }
    
    private func extractProfitAmount(from text: String) -> Double? {
        let patterns = [
            #"盈亏[金额]*[：:]\s*([+-]?\d+\.?\d*)\s*USDT"#,
            #"Profit/Loss[：:]\s*([+-]?\d+\.?\d*)\s*USDT"#,
            #"([+-]?\d+\.?\d*)\s*USDT"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                // 优先查找包含正负号的数字
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let value = String(text[range])
                        if let doubleValue = Double(value) {
                            return doubleValue
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractProfitRate(from text: String) -> Double? {
        let patterns = [
            #"盈亏率[：:]\s*([+-]?\d+\.?\d*)%"#,
            #"Return Rate[：:]\s*([+-]?\d+\.?\d*)%"#,
            #"([+-]?\d+\.?\d*)%"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let value = String(text[range])
                        if let doubleValue = Double(value) {
                            return doubleValue / 100.0 // 转换为小数
                        }
                    }
                }
            }
        }
        
        return nil
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parseFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图片"
        case .noTextFound:
            return "图片中未识别到文本"
        case .parseFailed:
            return "无法解析交易数据"
        }
    }
}

