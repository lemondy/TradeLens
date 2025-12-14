//
//  CapitalView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import Charts
import CoreData

struct CapitalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trade.closeTime, ascending: true)],
        animation: .default)
    private var trades: FetchedResults<Trade>
    
    @AppStorage("initialEquity") private var initialEquity: Double = 10000.0
    @State private var timeRange: TimeRange = .all
    
    enum TimeRange: String, CaseIterable {
        case week = "周"
        case month = "月"
        case quarter = "季度"
        case all = "全部"
    }
    
    private var equityData: [EquityPoint] {
        let sortedTrades = Array(trades).sorted { ($0.closeTime ?? Date.distantPast) < ($1.closeTime ?? Date.distantPast) }
        var equity = initialEquity
        var points: [EquityPoint] = [EquityPoint(date: Date().addingTimeInterval(-86400 * 365), equity: initialEquity)]
        
        for trade in sortedTrades {
            guard let closeTime = trade.closeTime else { continue }
            equity += trade.profitAmount
            points.append(EquityPoint(date: closeTime, equity: equity))
        }
        
        // 过滤时间范围
        let now = Date()
        let cutoff: Date? = {
            switch timeRange {
            case .week:
                return Calendar.current.date(byAdding: .day, value: -7, to: now)
            case .month:
                return Calendar.current.date(byAdding: .month, value: -1, to: now)
            case .quarter:
                return Calendar.current.date(byAdding: .month, value: -3, to: now)
            case .all:
                return nil
            }
        }()
        
        if let cutoff = cutoff {
            return points.filter { $0.date >= cutoff }
        }
        
        return points
    }
    
    private var metrics: TradingMetrics {
        TradingMetrics.calculate(from: Array(trades), initialEquity: initialEquity)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("资金曲线")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Picker("时间范围", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding()
            
            Divider()
            
            // 图表
            if equityData.count > 1 {
                Chart(equityData) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("净值", point.equity)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("净值", point.equity)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: equityData.count > 30 ? 7 : 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let equity = value.as(Double.self) {
                                Text(String(format: "%.0f", equity))
                            }
                        }
                    }
                }
                .frame(height: 400)
                .padding()
            } else {
                ContentUnavailableView(
                    "暂无数据",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("请先添加交易记录以生成资金曲线")
                )
            }
            
            Divider()
            
            // 指标面板
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(title: "总盈亏", value: String(format: "%.2f USDT", metrics.totalProfit), color: metrics.totalProfit >= 0 ? .green : .red)
                    MetricCard(title: "胜率", value: String(format: "%.1f%%", metrics.winRate * 100), color: .primary)
                    MetricCard(title: "盈亏比", value: String(format: "%.2f", metrics.profitLossRatio), color: .primary)
                    MetricCard(title: "最大回撤", value: String(format: "%.2f%%", metrics.maxDrawdown * 100), color: .red)
                    MetricCard(title: "平均盈利", value: String(format: "%.2f", metrics.avgWin), color: .green)
                    MetricCard(title: "平均亏损", value: String(format: "%.2f", metrics.avgLoss), color: .red)
                    MetricCard(title: "总交易数", value: "\(metrics.totalTrades)", color: .primary)
                    MetricCard(title: "当前净值", value: String(format: "%.2f", metrics.currentEquity), color: .primary)
                }
                .padding()
            }
            .frame(height: 200)
        }
    }
}

struct EquityPoint: Identifiable {
    let id = UUID()
    let date: Date
    let equity: Double
}

struct TradingMetrics {
    let totalProfit: Double
    let winRate: Double
    let profitLossRatio: Double
    let maxDrawdown: Double
    let avgWin: Double
    let avgLoss: Double
    let totalTrades: Int
    let currentEquity: Double
    
    static func calculate(from trades: [Trade], initialEquity: Double) -> TradingMetrics {
        guard !trades.isEmpty else {
            return TradingMetrics(
                totalProfit: 0,
                winRate: 0,
                profitLossRatio: 0,
                maxDrawdown: 0,
                avgWin: 0,
                avgLoss: 0,
                totalTrades: 0,
                currentEquity: initialEquity
            )
        }
        
        let totalProfit = trades.reduce(0) { $0 + $1.profitAmount }
        let wins = trades.filter { $0.status == "win" }
        let losses = trades.filter { $0.status == "loss" }
        let winRate = Double(wins.count) / Double(trades.count)
        
        let avgWin = wins.isEmpty ? 0 : wins.map { $0.profitAmount }.reduce(0, +) / Double(wins.count)
        let avgLoss = losses.isEmpty ? 0 : abs(losses.map { $0.profitAmount }.reduce(0, +) / Double(losses.count))
        let profitLossRatio = avgLoss > 0 ? avgWin / avgLoss : 0
        
        // 计算最大回撤
        let sortedTrades = trades.sorted { ($0.closeTime ?? Date.distantPast) < ($1.closeTime ?? Date.distantPast) }
        var equity = initialEquity
        var peak = initialEquity
        var maxDrawdown: Double = 0
        
        for trade in sortedTrades {
            equity += trade.profitAmount
            if equity > peak {
                peak = equity
            }
            let drawdown = (peak - equity) / peak
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }
        
        return TradingMetrics(
            totalProfit: totalProfit,
            winRate: winRate,
            profitLossRatio: profitLossRatio,
            maxDrawdown: maxDrawdown,
            avgWin: avgWin,
            avgLoss: avgLoss,
            totalTrades: trades.count,
            currentEquity: initialEquity + totalProfit
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    CapitalView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

