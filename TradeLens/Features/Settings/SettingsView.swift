//
//  SettingsView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("initialEquity") private var initialEquity: Double = 10000.0
    @State private var apiKey: String = ""
    @State private var showingAPIKeyInput = false
    @State private var tempAPIKey: String = ""
    
    var body: some View {
        Form {
            Section("账户设置") {
                TextField("初始资金 (USDT)", value: $initialEquity, format: .number)
                    .help("用于计算资金曲线和回撤")
            }
            
            Section("AI 设置") {
                HStack {
                    Text("Gemini API Key")
                    Spacer()
                    if SecurityService.shared.hasAPIKey() {
                        Text("已配置")
                            .foregroundStyle(.green)
                    } else {
                        Text("未配置")
                            .foregroundStyle(.red)
                    }
                    Button("配置") {
                        tempAPIKey = SecurityService.shared.getAPIKey() ?? ""
                        showingAPIKeyInput = true
                    }
                }
                
                Text("使用 Gemini API 进行智能复盘分析")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("数据与隐私") {
                Text("所有数据存储在本地，不会上传到任何服务器")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("导出数据") {
                    // TODO: 实现数据导出
                }
                
                Button(role: .destructive) {
                    // TODO: 实现数据清除
                } label: {
                    Text("清除所有数据")
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Link("帮助文档", destination: URL(string: "https://github.com/tradelens")!)
                Link("反馈问题", destination: URL(string: "https://github.com/tradelens/issues")!)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAPIKeyInput) {
            APIKeyInputSheet(apiKey: $tempAPIKey) {
                if !tempAPIKey.isEmpty {
                    SecurityService.shared.saveAPIKey(tempAPIKey)
                }
                showingAPIKeyInput = false
            }
        }
    }
}

struct APIKeyInputSheet: View {
    @Binding var apiKey: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("请输入您的 Gemini API Key")
                    .font(.headline)
                
                Text("您可以在 [Google AI Studio](https://makersuite.google.com/app/apikey) 获取 API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                Text("API Key 将安全存储在系统 Keychain 中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("配置 API Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .frame(width: 500, height: 200)
        }
    }
}

#Preview {
    SettingsView()
}

