//
//  RootView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI

enum SidebarItem: Hashable {
    case tradeLog
    case reviewEditor
    case capital
    case aiReview
    case templates
    case settings
}

struct RootView: View {
    @State private var selection: SidebarItem? = .tradeLog

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("记录与复盘") {
                    NavigationLink(value: SidebarItem.tradeLog) {
                        Label("交易记录", systemImage: "list.bullet")
                    }
                    NavigationLink(value: SidebarItem.reviewEditor) {
                        Label("复盘编辑器", systemImage: "square.and.pencil")
                    }
                }
                
                Section("分析") {
                    NavigationLink(value: SidebarItem.capital) {
                        Label("资金曲线", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink(value: SidebarItem.aiReview) {
                        Label("AI 智能复盘", systemImage: "brain.head.profile")
                    }
                }
                
                Section("配置") {
                    NavigationLink(value: SidebarItem.templates) {
                        Label("模板管理", systemImage: "doc.richtext")
                    }
                    NavigationLink(value: SidebarItem.settings) {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("TradeLens")
        } detail: {
            Group {
                switch selection {
                case .tradeLog:
                    TradeLogView()
                case .reviewEditor:
                    ReviewEditorRootView()
                case .capital:
                    CapitalView()
                case .aiReview:
                    AIReviewView()
                case .templates:
                    TemplateListView()
                case .settings:
                    SettingsView()
                case .none:
                    ContentUnavailableView(
                        "选择左侧菜单开始使用 TradeLens",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("请从左侧导航栏选择一个功能模块")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

