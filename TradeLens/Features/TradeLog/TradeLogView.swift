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
    @State private var showingCSVImporter = false
    @State private var recognizedTrades: [TradeData] = []
    @State private var showingBatchConfirm = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("导入方式") {
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
                    
                    Button {
                        showingCSVImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("从 CSV 文件导入")
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
            .sheet(isPresented: $showingBatchConfirm) {
                BatchTradeConfirmSheet(
                    trades: recognizedTrades,
                    onConfirm: { selectedTrades in
                        saveBatchTrades(selectedTrades)
                        showingBatchConfirm = false
                    },
                    onCancel: {
                        showingBatchConfirm = false
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
            .fileImporter(
                isPresented: $showingImagePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // 开始访问安全作用域资源
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if accessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                        if let image = NSImage(contentsOf: url) {
                            recognizeFromImage(image)
                        }
                    }
                case .failure(let error):
                    ocrError = "选择文件失败: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // 开始访问安全作用域资源
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if accessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                        importFromCSV(url: url)
                    }
                case .failure(let error):
                    ocrError = "选择 CSV 文件失败: \(error.localizedDescription)"
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
        recognizedTrades = []
        
        Task {
            do {
                let text = try await recognizeText(from: image)
                print("OCR 识别结果:\n\(text)")
                
                // 尝试解析多笔交易
                let trades = parseMultipleTrades(from: text)
                
                await MainActor.run {
                    isProcessingOCR = false
                    
                    if trades.isEmpty {
                        // 如果没有识别到多笔交易，尝试单笔解析
                        if let tradeData = parseTradeData(from: text) {
                            fillForm(with: tradeData)
                        } else {
                            ocrError = "无法从图片中解析交易数据，请检查图片内容"
                        }
                    } else if trades.count == 1 {
                        // 如果只有一笔，直接填充表单
                        fillForm(with: trades[0])
                    } else {
                        // 多笔交易，显示批量确认界面
                        recognizedTrades = trades
                        showingBatchConfirm = true
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
    
    private func importFromCSV(url: URL) {
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            print("CSV 内容预览:\n\(csvContent.prefix(500))")
            let trades = parseCSV(csvContent: csvContent)
            print("解析到 \(trades.count) 笔交易")
            
            if trades.isEmpty {
                ocrError = "CSV 文件中未找到有效的交易数据，请检查文件格式"
            } else if trades.count == 1 {
                fillForm(with: trades[0])
            } else {
                recognizedTrades = trades
                showingBatchConfirm = true
            }
        } catch {
            ocrError = "读取 CSV 文件失败: \(error.localizedDescription)"
        }
    }
    
    private func parseCSV(csvContent: String) -> [TradeData] {
        var trades: [TradeData] = []
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else { return [] }
        
        // 解析表头
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)
        
        // 清理表头（移除引号和空格）
        let cleanedHeaders = headers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").lowercased() }
        print("表头: \(cleanedHeaders)")
        
        // 查找列索引（更灵活的匹配）
        let symbolIndex = cleanedHeaders.firstIndex(where: { $0 == "symbol" })
        let sideIndex = cleanedHeaders.firstIndex(where: { $0.contains("position side") || $0.contains("side") && !$0.contains("margin") })
        let entryPriceIndex = cleanedHeaders.firstIndex(where: { $0.contains("entry price") || $0.contains("开仓价格") })
        // 注意：处理拼写错误 "Pirce" -> "Price"
        let closePriceIndex = cleanedHeaders.firstIndex(where: { 
            $0.contains("close") && ($0.contains("price") || $0.contains("pirce")) || 
            $0.contains("avg") && ($0.contains("close") || $0.contains("平仓价格"))
        })
        let volumeIndex = cleanedHeaders.firstIndex(where: { 
            $0.contains("closed vol") || $0.contains("volume") || 
            $0.contains("vol.") || $0.contains("仓位")
        })
        let pnlIndex = cleanedHeaders.firstIndex(where: { 
            $0.contains("closing pnl") || $0.contains("pnl") || 
            $0.contains("盈亏")
        })
        let openedIndex = cleanedHeaders.firstIndex(where: { 
            $0 == "opened" || $0.contains("开仓时间")
        })
        let closedIndex = cleanedHeaders.firstIndex(where: { 
            $0 == "closed" || $0.contains("平仓时间")
        })
        
        print("列索引 - symbol: \(symbolIndex?.description ?? "nil"), entryPrice: \(entryPriceIndex?.description ?? "nil"), closePrice: \(closePriceIndex?.description ?? "nil")")
        
        guard let symbolIdx = symbolIndex,
              let entryPriceIdx = entryPriceIndex,
              let closePriceIdx = closePriceIndex else {
            print("缺少必要的列: symbol=\(symbolIndex != nil), entryPrice=\(entryPriceIndex != nil), closePrice=\(closePriceIndex != nil)")
            return []
        }
        
        // 解析数据行
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            
            guard values.count > max(symbolIdx, entryPriceIdx, closePriceIdx) else { continue }
            
            var trade = TradeData()
            
            // 交易对
            trade.symbol = values[symbolIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            
            // 方向
            if let sideIdx = sideIndex, sideIdx < values.count {
                let sideValue = values[sideIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").lowercased()
                trade.side = (sideValue == "long" || sideValue == "做多") ? "long" : "short"
            }
            
            // 开仓价格
            if let entryPrice = Double(values[entryPriceIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")) {
                trade.openPrice = entryPrice
            }
            
            // 平仓价格
            if let closePrice = Double(values[closePriceIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")) {
                trade.closePrice = closePrice
            }
            
            // 仓位大小
            if let volIdx = volumeIndex, volIdx < values.count,
               let volume = Double(values[volIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")) {
                trade.positionSize = volume
            }
            
            // 盈亏金额
            if let pnlIdx = pnlIndex, pnlIdx < values.count,
               let pnl = Double(values[pnlIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")) {
                trade.profitAmount = pnl
            }
            
            // 开仓时间
            if let openedIdx = openedIndex, openedIdx < values.count {
                let dateString = values[openedIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                trade.openTime = parseCSVDate(dateString)
            }
            
            // 平仓时间
            if let closedIdx = closedIndex, closedIdx < values.count {
                let dateString = values[closedIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                trade.closeTime = parseCSVDate(dateString)
            }
            
            // 默认杠杆
            trade.leverage = 10
            
            // 验证必要字段
            if !trade.symbol.isEmpty && trade.openPrice > 0 && trade.closePrice > 0 {
                // 如果仓位大小为0但盈亏金额不为0，尝试从盈亏金额反推仓位大小
                if trade.positionSize == 0 && trade.profitAmount != 0 {
                    let priceDiff = abs(trade.closePrice - trade.openPrice)
                    if priceDiff > 0 {
                        trade.positionSize = abs(trade.profitAmount) / priceDiff
                    }
                }
                
                // 如果开仓时间为空，使用平仓时间
                if trade.openTime == nil {
                    trade.openTime = trade.closeTime
                }
                
                // 如果平仓时间为空，使用开仓时间
                if trade.closeTime == nil {
                    trade.closeTime = trade.openTime ?? Date()
                }
                
                trades.append(trade)
                print("成功解析交易: \(trade.symbol), 开仓: \(trade.openPrice), 平仓: \(trade.closePrice)")
            } else {
                print("跳过无效交易: symbol=\(trade.symbol), openPrice=\(trade.openPrice), closePrice=\(trade.closePrice)")
            }
        }
        
        print("总共解析到 \(trades.count) 笔有效交易")
        return trades
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var previousChar: Character? = nil
        
        for char in line {
            if char == "\"" {
                // 处理转义的引号 ""
                if previousChar == "\"" && insideQuotes {
                    currentField.append("\"")
                    previousChar = nil
                    continue
                }
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            previousChar = char
        }
        // 添加最后一个字段
        fields.append(currentField)
        
        return fields
    }
    
    private func parseCSVDate(_ dateString: String) -> Date? {
        let cleanedDateString = dateString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        
        // 尝试多种日期格式（按常见程度排序）
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSS",  // 2025-12-11 11:10:33.737
            "yyyy-MM-dd HH:mm:ss",      // 2025-12-11 11:10:33
            "yyyy/MM/dd HH:mm:ss",      // 2025/12/11 11:10:33
            "MM/dd/yyyy HH:mm:ss",      // 12/11/2025 11:10:33
            "yyyy-MM-dd",               // 2025-12-11
            "yyyy/MM/dd",                // 2025/12/11
            "MM/dd/yyyy"                // 12/11/2025
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: cleanedDateString) {
                return date
            }
        }
        
        // 如果所有格式都失败，尝试使用 ISO8601DateFormatter
        if #available(macOS 10.12, *) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: cleanedDateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func saveBatchTrades(_ trades: [TradeData]) {
        for tradeData in trades {
            let trade = Trade(context: viewContext)
            trade.id = UUID()
            trade.symbol = tradeData.symbol.uppercased()
            trade.side = tradeData.side
            trade.openTime = tradeData.openTime ?? Date()
            trade.closeTime = tradeData.closeTime ?? Date()
            trade.openPrice = tradeData.openPrice
            trade.closePrice = tradeData.closePrice
            trade.leverage = Int16(tradeData.leverage)
            trade.positionSize = tradeData.positionSize
            
            // 计算盈亏
            let priceDiff = tradeData.closePrice - tradeData.openPrice
            let multiplier = tradeData.side == "long" ? 1.0 : -1.0
            let pnl = priceDiff * multiplier * tradeData.positionSize
            trade.profitAmount = pnl
            
            // 计算盈亏率
            let priceChangeRate = tradeData.openPrice > 0 ? 
                (tradeData.closePrice - tradeData.openPrice) / tradeData.openPrice * multiplier : 0
            trade.profitRate = priceChangeRate * Double(tradeData.leverage)
            
            if pnl > 0 {
                trade.status = "win"
            } else if pnl < 0 {
                trade.status = "loss"
            } else {
                trade.status = "breakeven"
            }
            
            trade.source = "ocr"
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("批量保存交易失败: \(error)")
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
    
    /// 从 OCR 文本中解析多笔交易数据
    func parseMultipleTrades(from text: String) -> [TradeData] {
        var trades: [TradeData] = []
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // 策略1: 按交易对分割（每个USDT结尾的字符串可能是一笔交易）
        let symbolPattern = #"([A-Z0-9]+USDT)"#
        if let regex = try? NSRegularExpression(pattern: symbolPattern, options: .caseInsensitive) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            // 如果找到多个交易对，尝试为每个交易对解析数据
            if matches.count > 1 {
                for (index, match) in matches.enumerated() {
                    guard let symbolRange = Range(match.range(at: 1), in: text) else { continue }
                    let symbol = String(text[symbolRange])
                    
                    // 确定当前交易对的文本范围
                    let startRange = match.range
                    let endRange = index < matches.count - 1 ? matches[index + 1].range : NSRange(location: nsString.length, length: 0)
                    
                    let tradeTextRange = NSRange(location: startRange.location, length: endRange.location - startRange.location)
                    if let tradeTextRange = Range(tradeTextRange, in: text) {
                        let tradeText = String(text[tradeTextRange])
                        
                        if let tradeData = parseTradeData(from: tradeText, defaultSymbol: symbol) {
                            trades.append(tradeData)
                        }
                    }
                }
            }
        }
        
        // 策略2: 如果策略1没找到多笔，尝试按行分割（每行可能是一笔交易）
        if trades.isEmpty && lines.count > 3 {
            // 尝试将文本按行分组，每组可能是一笔交易
            var currentTradeLines: [String] = []
            
            for line in lines {
                // 如果这一行包含交易对，可能是新交易的开始
                if line.range(of: #"[A-Z0-9]+USDT"#, options: .regularExpression) != nil {
                    if !currentTradeLines.isEmpty {
                        let tradeText = currentTradeLines.joined(separator: "\n")
                        if let tradeData = parseTradeData(from: tradeText) {
                            trades.append(tradeData)
                        }
                    }
                    currentTradeLines = [line]
                } else {
                    currentTradeLines.append(line)
                }
            }
            
            // 处理最后一组
            if !currentTradeLines.isEmpty {
                let tradeText = currentTradeLines.joined(separator: "\n")
                if let tradeData = parseTradeData(from: tradeText) {
                    trades.append(tradeData)
                }
            }
        }
        
        // 策略3: 如果前两种策略都没找到，尝试按重复模式识别（例如每3-5行是一笔交易）
        if trades.isEmpty && lines.count >= 6 {
            // 假设每3-5行是一笔交易，尝试分组
            let linesPerTrade = max(3, lines.count / 3) // 至少3行，最多分成3组
            
            for i in stride(from: 0, to: lines.count, by: linesPerTrade) {
                let endIndex = min(i + linesPerTrade, lines.count)
                let tradeLines = Array(lines[i..<endIndex])
                let tradeText = tradeLines.joined(separator: "\n")
                
                if let tradeData = parseTradeData(from: tradeText) {
                    trades.append(tradeData)
                }
            }
        }
        
        // 过滤掉无效的交易（必须有交易对和价格）
        let validTrades = trades.filter { !$0.symbol.isEmpty && $0.openPrice > 0 && $0.closePrice > 0 }
        
        // 如果识别到多笔有效交易，返回它们
        if validTrades.count > 1 {
            return validTrades
        }
        
        return []
    }
    
    /// 从 OCR 文本中解析交易数据
    func parseTradeData(from text: String, defaultSymbol: String? = nil) -> TradeData? {
        var tradeData = TradeData()
        let fullText = text.replacingOccurrences(of: "\n", with: " ")
        
        // 解析交易对
        if let symbol = extractSymbol(from: fullText) {
            tradeData.symbol = symbol
        } else if let defaultSymbol = defaultSymbol {
            tradeData.symbol = defaultSymbol
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

struct BatchTradeConfirmSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let trades: [TradeData]
    let onConfirm: ([TradeData]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedTrades: Set<Int> = []
    
    private var isAllSelected: Bool {
        !trades.isEmpty && selectedTrades.count == trades.count
    }
    
    private var selectedCount: Int {
        selectedTrades.count
    }
    
    private func toggleSelectAll() {
        if isAllSelected {
            selectedTrades.removeAll()
        } else {
            selectedTrades = Set(0..<trades.count)
        }
    }
    
    private func toggleTrade(at index: Int) {
        if selectedTrades.contains(index) {
            selectedTrades.remove(index)
        } else {
            selectedTrades.insert(index)
        }
    }
    
    private func confirmImport() {
        let selected = selectedTrades.sorted().compactMap { index -> TradeData? in
            guard index < trades.count else { return nil }
            return trades[index]
        }
        onConfirm(selected)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                Divider()
                tradeListView
                Divider()
                footerView
            }
            .frame(width: 700, height: 500)
            .navigationTitle("批量导入交易")
            .onAppear {
                // 默认全选所有交易
                selectedTrades = Set(0..<trades.count)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("识别到 \(trades.count) 笔交易")
                .font(.headline)
            Spacer()
            Button(isAllSelected ? "取消全选" : "全选") {
                toggleSelectAll()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var tradeListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<trades.count, id: \.self) { index in
                    tradeRow(at: index)
                    if index < trades.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
    
    private func tradeRow(at index: Int) -> some View {
        HStack {
            Button {
                toggleTrade(at: index)
            } label: {
                Image(systemName: selectedTrades.contains(index) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selectedTrades.contains(index) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            TradeDataRow(trade: trades[index], index: index)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    private var footerView: some View {
        HStack {
            Text("已选择 \(selectedCount) 笔交易")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("取消") {
                onCancel()
            }
            .buttonStyle(.bordered)
            
            Button("确认导入") {
                confirmImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTrades.isEmpty)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TradeDataRow: View {
    let trade: TradeData
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // 交易对和方向
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.symbol.isEmpty ? "未知交易对" : trade.symbol)
                        .font(.headline)
                    Text(trade.side == "long" ? "做多" : "做空")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trade.side == "long" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundStyle(trade.side == "long" ? .green : .red)
                        .cornerRadius(4)
                }
                
                if let closeTime = trade.closeTime {
                    Text(closeTime, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 价格信息
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Text("开仓:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", trade.openPrice))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                HStack(spacing: 8) {
                    Text("平仓:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", trade.closePrice))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            
            // 盈亏信息
            VStack(alignment: .trailing, spacing: 4) {
                let pnl = calculateProfit()
                HStack(spacing: 4) {
                    Text(String(format: "%.2f", pnl))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                    Text("USDT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if trade.leverage > 0 {
                    Text("\(trade.leverage)x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func calculateProfit() -> Double {
        let priceDiff = trade.closePrice - trade.openPrice
        let multiplier = trade.side == "long" ? 1.0 : -1.0
        return priceDiff * multiplier * trade.positionSize
    }
}

#Preview {
    TradeLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

