//
//  TradeLogView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import CoreData

struct TradeLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trade.closeTime, ascending: false)],
        animation: .default)
    private var trades: FetchedResults<Trade>
    
    @State private var showingNewTradeSheet = false
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
                }
                .tableStyle(.inset)
            }
        }
        .sheet(isPresented: $showingNewTradeSheet) {
            NewTradeSheet()
                .environment(\.managedObjectContext, viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTradeShortcut)) { _ in
            showingNewTradeSheet = true
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
        trade.profitRate = openPrice > 0 ? pnl / (openPrice * positionSize) : 0
        
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

#Preview {
    TradeLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

