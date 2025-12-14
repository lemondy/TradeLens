//
//  TradeLogView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import CoreData
import AppKit
import Vision

struct TradeLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trade.closeTime, ascending: false)],
        animation: .default)
    private var trades: FetchedResults<Trade>
    
    @State private var showingNewTradeSheet = false
    @State private var showingEditTradeSheet = false
    @State private var tradeToEdit: Trade?
    @State private var selectedTradeID: Trade.ID?
    @State private var filterSymbol: String = ""
    @State private var filterStatus: String = "全部"
    @State private var sortBy: SortOption = .time
    
    enum SortOption: String, CaseIterable {
        case time = "时间"
        case profit = "盈亏"
        case symbol = "交易对"
    }
    
    private var filteredTrades: [Trade] {
        var result = Array(trades)
        
        if !filterSymbol.isEmpty {
            result = result.filter { ($0.symbol ?? "").localizedCaseInsensitiveContains(filterSymbol) }
        }
        
        if filterStatus != "全部" {
            result = result.filter { ($0.status ?? "") == filterStatus }
        }
        
        switch sortBy {
        case .time:
            result.sort { ($0.closeTime ?? Date.distantPast) > ($1.closeTime ?? Date.distantPast) }
        case .profit:
            result.sort { $0.profitAmount > $1.profitAmount }
        case .symbol:
            result.sort { ($0.symbol ?? "") < ($1.symbol ?? "") }
        }
        
        return result
    }
    
    private var totalProfit: Double {
        filteredTrades.reduce(0) { $0 + $1.profitAmount }
    }
    
    private var winRate: Double {
        let wins = filteredTrades.filter { $0.status == "win" }.count
        return filteredTrades.isEmpty ? 0 : Double(wins) / Double(filteredTrades.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("交易记录")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                // 筛选和排序
                HStack(spacing: 12) {
                    TextField("搜索交易对", text: $filterSymbol)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    
                    Picker("状态", selection: $filterStatus) {
                        Text("全部").tag("全部")
                        Text("盈利").tag("win")
                        Text("亏损").tag("loss")
                        Text("保本").tag("breakeven")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    
                    Picker("排序", selection: $sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                Button {
                    showingNewTradeSheet = true
                } label: {
                    Label("新建交易", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // 统计信息栏
            HStack(spacing: 24) {
                StatItem(title: "总交易数", value: "\(filteredTrades.count)")
                StatItem(title: "总盈亏", value: String(format: "%.2f USDT", totalProfit), color: totalProfit >= 0 ? .green : .red)
                StatItem(title: "胜率", value: String(format: "%.1f%%", winRate * 100))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 交易列表
            if filteredTrades.isEmpty {
                ContentUnavailableView(
                    "暂无交易记录",
                    systemImage: "list.bullet",
                    description: Text("点击右上角「新建交易」按钮开始记录您的第一笔交易")
                )
            } else {
                Table(filteredTrades, selection: $selectedTradeID) {
                    TableColumn("时间") { trade in
                        Text(trade.closeTime ?? Date(), style: .date)
                            .font(.system(size: 12))
                    }
                    .width(min: 120, ideal: 150)
                    
                    TableColumn("交易对") { trade in
                        Text(trade.symbol ?? "-")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)
                    
                    TableColumn("方向") { trade in
                        HStack {
                            Image(systemName: trade.side == "long" ? "arrow.up" : "arrow.down")
                                .foregroundStyle(trade.side == "long" ? .green : .red)
                            Text(trade.side == "long" ? "做多" : "做空")
                        }
                        .font(.system(size: 12))
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("开仓价格") { trade in
                        Text(String(format: "%.2f", trade.openPrice))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)
                    
                    TableColumn("平仓价格") { trade in
                        Text(String(format: "%.2f", trade.closePrice))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)
                    
                    TableColumn("杠杆") { trade in
                        Text("\(trade.leverage)x")
                            .font(.system(size: 12))
                    }
                    .width(min: 60, ideal: 80)
                    
                    TableColumn("盈亏金额") { trade in
                        Text(String(format: "%.2f", trade.profitAmount))
                            .foregroundStyle(trade.profitAmount >= 0 ? .green : .red)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .width(min: 100, ideal: 120)
                    
                    TableColumn("盈亏率") { trade in
                        Text(String(format: "%.2f%%", trade.profitRate * 100))
                            .foregroundStyle(trade.profitRate >= 0 ? .green : .red)
                            .font(.system(size: 12))
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("状态") { trade in
                        StatusBadge(status: trade.status ?? "")
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("复盘状态") { trade in
                        ReviewStatusBadge(hasReview: trade.review != nil)
                    }
                    .width(min: 90, ideal: 100)
                }
                .tableStyle(.inset)
                .contextMenu {
                    if let tradeID = selectedTradeID,
                       let trade = filteredTrades.first(where: { $0.id == tradeID }) {
                        Button {
                            tradeToEdit = trade
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            deleteTrade(trade)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } else {
                        Text("请先选择一条交易记录")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTradeSheet) {
            NewTradeSheet()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $tradeToEdit) { trade in
            EditTradeSheet(trade: trade)
                .environment(\.managedObjectContext, viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTradeShortcut)) { _ in
            showingNewTradeSheet = true
        }
    }
    
    private func deleteTrade(_ trade: Trade) {
        viewContext.delete(trade)
        do {
            try viewContext.save()
        } catch {
            print("删除交易失败: \(error)")
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        let (text, color) = {
            switch status {
            case "win": return ("盈利", Color.green)
            case "loss": return ("亏损", Color.red)
            case "breakeven": return ("保本", Color.gray)
            default: return ("未知", Color.gray)
            }
        }()
        
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

struct ReviewStatusBadge: View {
    let hasReview: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: hasReview ? "checkmark.circle.fill" : "circle")
                .font(.caption)
            Text(hasReview ? "已复盘" : "未复盘")
                .font(.caption)
        }
        .foregroundStyle(hasReview ? .blue : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(hasReview ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

struct TradeCellView<Content: View>: View {
    let trade: Trade
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
    }
}

struct NewTradeSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol = ""
    @State private var side = "long"
    @State private var openTime = Date()
    @State private var closeTime = Date()
    @State private var openPrice: Double = 0
    @State private var closePrice: Double = 0
    @State private var leverage: Int = 10
    @State private var positionSize: Double = 0
    
    @State private var isProcessingOCR = false
    @State private var ocrError: String?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("OCR 识别") {
                    Button {
                        recognizeFromClipboard()
                    } label: {
                        HStack {
                            if isProcessingOCR {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "camera.viewfinder")
                            }
                            Text(isProcessingOCR ? "识别中..." : "从剪贴板识别交易流水")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isProcessingOCR)
                    
                    Button {
                        selectImageFile()
                    } label: {
                        HStack {
                            Image(systemName: "photo")
                            Text("选择图片文件")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isProcessingOCR)
                    
                    if let error = ocrError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section("基本信息") {
                    TextField("交易对（例如 BTCUSDT）", text: $symbol)
                    Picker("方向", selection: $side) {
                        Text("做多").tag("long")
                        Text("做空").tag("short")
                    }
                }
                
                Section("时间") {
                    DatePicker("开仓时间", selection: $openTime)
                    DatePicker("平仓时间", selection: $closeTime)
                }
                
                Section("价格与仓位") {
                    TextField("开仓价格", value: $openPrice, format: .number)
                    TextField("平仓价格", value: $closePrice, format: .number)
                    TextField("杠杆", value: $leverage, format: .number)
                    TextField("仓位大小", value: $positionSize, format: .number)
                }
                
                if openPrice > 0 && closePrice > 0 && positionSize > 0 {
                    Section("计算结果") {
                        let pnl = calculateProfit()
                        let pnlRate = openPrice > 0 ? pnl / (openPrice * positionSize) : 0
                        
                        HStack {
                            Text("盈亏金额:")
                            Spacer()
                            Text(String(format: "%.2f USDT", pnl))
                                .foregroundStyle(pnl >= 0 ? .green : .red)
                        }
                        HStack {
                            Text("盈亏率:")
                            Spacer()
                            Text(String(format: "%.2f%%", pnlRate * 100))
                                .foregroundStyle(pnlRate >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新建交易")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(symbol.isEmpty || openPrice <= 0 || closePrice <= 0 || positionSize <= 0)
                }
            }
            .frame(width: 500, height: 600)
            .fileImporter(
                isPresented: $showingImagePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first,
                       let image = NSImage(contentsOf: url) {
                        recognizeFromImage(image)
                    }
                case .failure(let error):
                    ocrError = "选择文件失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func recognizeFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            ocrError = "剪贴板中没有图片"
            return
        }
        
        recognizeFromImage(image)
    }
    
    private func selectImageFile() {
        showingImagePicker = true
    }
    
    private func recognizeFromImage(_ image: NSImage) {
        isProcessingOCR = true
        ocrError = nil
        
        Task {
            do {
                let text = try await recognizeText(from: image)
                print("OCR 识别结果:\n\(text)")
                
                if let tradeData = parseTradeData(from: text) {
                    await MainActor.run {
                        fillForm(with: tradeData)
                        isProcessingOCR = false
                    }
                } else {
                    await MainActor.run {
                        ocrError = "无法从图片中解析交易数据，请检查图片内容"
                        isProcessingOCR = false
                    }
                }
            } catch {
                await MainActor.run {
                    ocrError = "OCR 识别失败: \(error.localizedDescription)"
                    isProcessingOCR = false
                }
            }
        }
    }
    
    private func fillForm(with data: TradeData) {
        if !data.symbol.isEmpty {
            symbol = data.symbol
        }
        side = data.side
        if let openTime = data.openTime {
            self.openTime = openTime
        }
        if let closeTime = data.closeTime {
            self.closeTime = closeTime
        }
        if data.openPrice > 0 {
            openPrice = data.openPrice
        }
        if data.closePrice > 0 {
            closePrice = data.closePrice
        }
        if data.leverage > 0 {
            leverage = data.leverage
        }
        if data.positionSize > 0 {
            positionSize = data.positionSize
        }
    }
    
    private func calculateProfit() -> Double {
        let priceDiff = closePrice - openPrice
        let multiplier = side == "long" ? 1.0 : -1.0
        return priceDiff * multiplier * positionSize
    }
    
    private func save() {
        let trade = Trade(context: viewContext)
        trade.id = UUID()
        trade.symbol = symbol.uppercased()
        trade.side = side
        trade.openTime = openTime
        trade.closeTime = closeTime
        trade.openPrice = openPrice
        trade.closePrice = closePrice
        trade.leverage = Int16(leverage)
        trade.positionSize = positionSize
        
        let pnl = calculateProfit()
        trade.profitAmount = pnl
        
        // 盈亏率 = 实际波动 * 杠杆倍数
        // 实际波动 = (平仓价格 - 开仓价格) / 开仓价格 * 方向系数
        let priceChangeRate = openPrice > 0 ? (closePrice - openPrice) / openPrice * (side == "long" ? 1.0 : -1.0) : 0
        trade.profitRate = priceChangeRate * Double(leverage)
        
        if pnl > 0 {
            trade.status = "win"
        } else if pnl < 0 {
            trade.status = "loss"
        } else {
            trade.status = "breakeven"
        }
        
        trade.source = "manual"
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存交易失败: \(error)")
        }
    }
}

struct EditTradeSheet: View {
    @ObservedObject var trade: Trade
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol: String = ""
    @State private var side: String = "long"
    @State private var openTime: Date = Date()
    @State private var closeTime: Date = Date()
    @State private var openPrice: Double = 0
    @State private var closePrice: Double = 0
    @State private var leverage: Int = 10
    @State private var positionSize: Double = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("交易对（例如 BTCUSDT）", text: $symbol)
                    Picker("方向", selection: $side) {
                        Text("做多").tag("long")
                        Text("做空").tag("short")
                    }
                }
                
                Section("时间") {
                    DatePicker("开仓时间", selection: $openTime)
                    DatePicker("平仓时间", selection: $closeTime)
                }
                
                Section("价格与仓位") {
                    TextField("开仓价格", value: $openPrice, format: .number)
                    TextField("平仓价格", value: $closePrice, format: .number)
                    TextField("杠杆", value: $leverage, format: .number)
                    TextField("仓位大小", value: $positionSize, format: .number)
                }
                
                if openPrice > 0 && closePrice > 0 && positionSize > 0 {
                    Section("计算结果") {
                        let pnl = calculateProfit()
                        let priceChangeRate = openPrice > 0 ? (closePrice - openPrice) / openPrice * (side == "long" ? 1.0 : -1.0) : 0
                        let pnlRate = priceChangeRate * Double(leverage)
                        
                        HStack {
                            Text("盈亏金额:")
                            Spacer()
                            Text(String(format: "%.2f USDT", pnl))
                                .foregroundStyle(pnl >= 0 ? .green : .red)
                        }
                        HStack {
                            Text("盈亏率:")
                            Spacer()
                            Text(String(format: "%.2f%%", pnlRate * 100))
                                .foregroundStyle(pnlRate >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("编辑交易")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(symbol.isEmpty || openPrice <= 0 || closePrice <= 0 || positionSize <= 0)
                }
            }
            .frame(width: 500, height: 600)
            .onAppear {
                loadTrade()
            }
        }
    }
    
    private func loadTrade() {
        symbol = trade.symbol ?? ""
        side = trade.side ?? "long"
        openTime = trade.openTime ?? Date()
        closeTime = trade.closeTime ?? Date()
        openPrice = trade.openPrice
        closePrice = trade.closePrice
        leverage = Int(trade.leverage)
        positionSize = trade.positionSize
    }
    
    private func calculateProfit() -> Double {
        let priceDiff = closePrice - openPrice
        let multiplier = side == "long" ? 1.0 : -1.0
        return priceDiff * multiplier * positionSize
    }
    
    private func save() {
        trade.symbol = symbol.uppercased()
        trade.side = side
        trade.openTime = openTime
        trade.closeTime = closeTime
        trade.openPrice = openPrice
        trade.closePrice = closePrice
        trade.leverage = Int16(leverage)
        trade.positionSize = positionSize
        
        let pnl = calculateProfit()
        trade.profitAmount = pnl
        
        // 盈亏率 = 实际波动 * 杠杆倍数
        let priceChangeRate = openPrice > 0 ? (closePrice - openPrice) / openPrice * (side == "long" ? 1.0 : -1.0) : 0
        trade.profitRate = priceChangeRate * Double(leverage)
        
        if pnl > 0 {
            trade.status = "win"
        } else if pnl < 0 {
            trade.status = "loss"
        } else {
            trade.status = "breakeven"
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存交易失败: \(error)")
        }
    }
}

// MARK: - OCR 辅助类型和函数

struct TradeData {
    var symbol: String = ""
    var side: String = "long"
    var openTime: Date?
    var closeTime: Date?
    var openPrice: Double = 0
    var closePrice: Double = 0
    var leverage: Int = 10
    var positionSize: Double = 0
    var profitAmount: Double = 0
    var profitRate: Double = 0
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parseFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无效的图片"
        case .noTextFound: return "图片中未识别到文本"
        case .parseFailed: return "无法解析交易数据"
        }
    }
}

extension NewTradeSheet {
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
        let fullText = text.replacingOccurrences(of: "\n", with: " ")
        
        // 解析交易对
        if let symbol = extractSymbol(from: fullText) {
            tradeData.symbol = symbol
        }
        
        // 解析方向
        if fullText.contains("做多") || fullText.contains("Long") || fullText.contains("long") {
            tradeData.side = "long"
        } else if fullText.contains("做空") || fullText.contains("Short") || fullText.contains("short") {
            tradeData.side = "short"
        }
        
        // 解析时间
        tradeData.openTime = extractDate(from: fullText, keywords: ["开仓时间", "Open Time", "开仓"])
        tradeData.closeTime = extractDate(from: fullText, keywords: ["平仓时间", "Close Time", "平仓", "Average Close"])
        
        // 解析价格
        tradeData.openPrice = extractPrice(from: fullText, keywords: ["开仓价格", "Open Price", "开仓"]) ?? 0
        tradeData.closePrice = extractPrice(from: fullText, keywords: ["平仓价格", "Close Price", "Average Close Price", "平仓"]) ?? 0
        
        // 解析其他字段
        tradeData.leverage = extractLeverage(from: fullText) ?? 10
        tradeData.positionSize = extractPositionSize(from: fullText) ?? 0
        tradeData.profitAmount = extractProfitAmount(from: fullText) ?? 0
        tradeData.profitRate = extractProfitRate(from: fullText) ?? 0
        
        guard !tradeData.symbol.isEmpty, tradeData.openPrice > 0, tradeData.closePrice > 0 else {
            return nil
        }
        
        return tradeData
    }
    
    // MARK: - 辅助解析方法
    
    private func extractSymbol(from text: String) -> String? {
        let patterns = [#"([A-Z0-9]+USDT)"#, #"([A-Z0-9]+USDT\s*永续)"#, #"([A-Z0-9]+USDT\s*Perpetual)"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).replacingOccurrences(of: "永续", with: "")
                    .replacingOccurrences(of: "Perpetual", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private func extractDate(from text: String, keywords: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        let formats = ["yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "MM/dd/yyyy HH:mm:ss", "yyyy/MM/dd", "yyyy-MM-dd"]
        
        for keyword in keywords {
            if let range = text.range(of: keyword, options: .caseInsensitive) {
                let afterKeyword = String(text[range.upperBound...])
                for format in formats {
                    dateFormatter.dateFormat = format
                    let trimmed = afterKeyword.trimmingCharacters(in: .whitespaces)
                    if let date = dateFormatter.date(from: String(trimmed.prefix(19))) {
                        return date
                    }
                }
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
                let pricePattern = #"(\d+\.?\d*)\s*USDT"#
                if let regex = try? NSRegularExpression(pattern: pricePattern),
                   let match = regex.firstMatch(in: afterKeyword, range: NSRange(afterKeyword.startIndex..., in: afterKeyword)),
                   let matchRange = Range(match.range(at: 1), in: afterKeyword) {
                    return Double(String(afterKeyword[matchRange]))
                }
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
        let patterns = [#"杠杆[：:]\s*(\d+)"#, #"Leverage[：:]\s*(\d+)"#, #"(\d+)x"#, #"(\d+)X"#]
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
        let patterns = [#"仓位[大小]*[：:]\s*(\d+\.?\d*)"#, #"Position[：:]\s*(\d+\.?\d*)"#, #"Closed Quantity[：:]\s*(\d+\.?\d*)"#, #"最大持仓[：:]\s*(\d+\.?\d*)"#]
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
        let patterns = [#"盈亏[金额]*[：:]\s*([+-]?\d+\.?\d*)\s*USDT"#, #"Profit/Loss[：:]\s*([+-]?\d+\.?\d*)\s*USDT"#, #"([+-]?\d+\.?\d*)\s*USDT"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        if let value = Double(String(text[range])) {
                            return value
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func extractProfitRate(from text: String) -> Double? {
        let patterns = [#"盈亏率[：:]\s*([+-]?\d+\.?\d*)%"#, #"Return Rate[：:]\s*([+-]?\d+\.?\d*)%"#, #"([+-]?\d+\.?\d*)%"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        if let value = Double(String(text[range])) {
                            return value / 100.0
                        }
                    }
                }
            }
        }
        return nil
    }
}

#Preview {
    TradeLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

