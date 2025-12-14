//
//  TemplateListView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import CoreData

struct TemplateListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Template.name, ascending: true)],
        animation: .default)
    private var templates: FetchedResults<Template>
    
    @State private var showingNewTemplateSheet = false
    @State private var selectedTemplate: Template?
    @State private var editingTemplate: Template?
    
    var body: some View {
        HSplitView {
            // 左侧：模板列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("模板列表")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingNewTemplateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                Divider()
                
                List(templates, selection: $selectedTemplate) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(template.name ?? "未命名")
                                    .font(.headline)
                                if template.isDefault {
                                    Text("默认")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text("\(template.contentMarkdown?.count ?? 0) 字符")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .tag(template)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250, idealWidth: 300)
            
            // 右侧：模板编辑器
            if let template = selectedTemplate {
                TemplateEditorView(template: template)
            } else {
                ContentUnavailableView(
                    "选择或创建模板",
                    systemImage: "doc.richtext",
                    description: Text("从左侧列表选择一个模板进行编辑，或点击「+」创建新模板")
                )
            }
        }
        .sheet(isPresented: $showingNewTemplateSheet) {
            NewTemplateSheet()
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            createDefaultTemplatesIfNeeded()
        }
    }
    
    private func createDefaultTemplatesIfNeeded() {
        if templates.isEmpty {
            let defaultTemplates = [
                ("标准日内复盘", """
# 交易复盘

## 交易机会捕捉
- 入场理由：
- 技术指标：
- 市场环境：

## 执行情况
- 开仓时机：
- 平仓时机：
- 执行偏差：

## 心理状态
- 交易时情绪：
- 是否按计划执行：
- 心理偏差：

## 改进措施
- 下次改进：
- 需要避免的错误：

## 总结
"""),
                ("趋势跟踪复盘", """
# 趋势跟踪复盘

## 趋势识别
- 趋势方向：
- 趋势强度：
- 关键支撑/阻力：

## 入场与出场
- 入场信号：
- 止损位：
- 止盈位：
- 实际出场：

## 风险管理
- 仓位大小：
- 风险收益比：
- 是否遵守规则：

## 市场环境
- 市场情绪：
- 相关新闻：
- 技术面分析：

## 反思与改进
"""),
                ("大幅亏损分析", """
# 大幅亏损分析

## 亏损情况
- 亏损金额：{{盈亏金额}}
- 亏损率：{{盈亏率}}
- 交易对：{{交易对}}

## 原因分析
- 主要原因：
- 次要原因：
- 是否可避免：

## 执行问题
- 是否按止损执行：
- 是否过度交易：
- 是否情绪化交易：

## 教训总结
- 核心教训：
- 需要改进的地方：

## 预防措施
- 如何避免类似错误：
- 需要建立的规则：
""")
            ]
            
            for (index, (name, content)) in defaultTemplates.enumerated() {
                let template = Template(context: viewContext)
                template.id = UUID()
                template.name = name
                template.contentMarkdown = content
                template.isDefault = index == 0
            }
            
            try? viewContext.save()
        }
    }
}

struct TemplateEditorView: View {
    @ObservedObject var template: Template
    @Environment(\.managedObjectContext) private var viewContext
    @State private var name: String = ""
    @State private var content: String = ""
    @State private var isDefault: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                TextField("模板名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Toggle("设为默认模板", isOn: $isDefault)
                
                Spacer()
                
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .padding()
            
            Divider()
            
            // 编辑器
            VStack(alignment: .leading, spacing: 8) {
                Text("模板内容（支持变量：{{交易对}}、{{盈亏金额}}、{{盈亏率}}等）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .padding()
            }
        }
        .onAppear {
            loadTemplate()
        }
    }
    
    private func loadTemplate() {
        name = template.name ?? ""
        content = template.contentMarkdown ?? ""
        isDefault = template.isDefault
    }
    
    private func save() {
        template.name = name
        template.contentMarkdown = content
        
        // 如果设为默认，取消其他模板的默认状态
        if isDefault {
            let allTemplates = try? viewContext.fetch(Template.fetchRequest())
            allTemplates?.forEach { $0.isDefault = false }
        }
        template.isDefault = isDefault
        
        try? viewContext.save()
    }
    
    private func delete() {
        viewContext.delete(template)
        try? viewContext.save()
    }
}

struct NewTemplateSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("模板名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                Text("模板内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(height: 400)
            }
            .padding()
            .navigationTitle("新建模板")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        create()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .frame(width: 600, height: 500)
        }
    }
    
    private func create() {
        let template = Template(context: viewContext)
        template.id = UUID()
        template.name = name
        template.contentMarkdown = content
        template.isDefault = false
        
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    TemplateListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

