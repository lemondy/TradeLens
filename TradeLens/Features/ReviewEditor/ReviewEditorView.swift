//
//  ReviewEditorView.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI
import CoreData
import AppKit

struct ReviewEditorRootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Review.updatedAt, ascending: false)],
        animation: .default)
    private var reviews: FetchedResults<Review>
    
    @State private var selectedReview: Review?
    @State private var showingNewReviewSheet = false
    
    var body: some View {
        HSplitView {
            // 左侧：复盘列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("复盘列表")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingNewReviewSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                Divider()
                
                List(reviews, selection: $selectedReview) { review in
                    ReviewRow(review: review)
                        .tag(review)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250, idealWidth: 300)
            
            // 右侧：编辑器
            if let review = selectedReview {
                ReviewEditorView(review: review)
            } else {
                ContentUnavailableView(
                    "选择或创建复盘",
                    systemImage: "square.and.pencil",
                    description: Text("从左侧列表选择一笔复盘，或点击「+」创建新的复盘")
                )
            }
        }
        .sheet(isPresented: $showingNewReviewSheet) {
            NewReviewSheet()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

struct ReviewRow: View {
    @ObservedObject var review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let trade = review.trade {
                Text(trade.symbol ?? "未知交易对")
                    .font(.headline)
                Text(trade.closeTime ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("独立复盘")
                    .font(.headline)
            }
            
            if let tags = review.tags, !tags.isEmpty {
                HStack {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReviewEditorView: View {
    @ObservedObject var review: Review
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isEditorFocused: Bool
    
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                if let trade = review.trade {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trade.symbol ?? "未知")
                            .font(.headline)
                        Text("盈亏: \(String(format: "%.2f", trade.profitAmount)) USDT")
                            .font(.caption)
                            .foregroundStyle(trade.profitAmount >= 0 ? .green : .red)
                    }
                }
                
                Spacer()
                
                // 标签输入
                HStack {
                    TextField("添加标签", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit {
                            addTag()
                        }
                    
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // 标签显示
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            Divider()
            
            // Markdown 编辑器
            HSplitView {
                // 编辑区
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .focused($isEditorFocused)
                    .padding()
                    .frame(minWidth: 400)
                
                // 预览区
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(parseMarkdown(content))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .frame(minWidth: 400)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .onAppear {
            loadReview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pasteImageShortcut)) { _ in
            pasteImage()
        }
    }
    
    private func loadReview() {
        content = review.contentMarkdown ?? ""
        tags = review.tags ?? []
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }
    
    private func save() {
        review.contentMarkdown = content
        review.tags = tags
        review.updatedAt = Date()
        
        if review.createdAt == nil {
            review.createdAt = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            print("保存复盘失败: \(error)")
        }
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        // 简单的 Markdown 解析（实际项目中可以使用更完善的库）
        var attributed = AttributedString(text)
        
        // 处理粗体 **text**
        let boldPattern = #"\*\*(.+?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let stringRange = Range(match.range, in: text),
                   let attributedRange = Range(stringRange, in: attributed) {
                    let boldText = String(text[stringRange].dropFirst(2).dropLast(2))
                    var boldAttributed = AttributedString(boldText)
                    boldAttributed.font = .system(size: 14, weight: .bold)
                    attributed.replaceSubrange(attributedRange, with: boldAttributed)
                }
            }
        }
        
        return attributed
    }
    
    private func pasteImage() {
        let pasteboard = NSPasteboard.general
        guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            return
        }
        
        // 保存图片到本地
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tradeLensDir = appSupport.appendingPathComponent("TradeLens")
        let attachmentsDir = tradeLensDir.appendingPathComponent("attachments")
        
        try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        
        let imageName = UUID().uuidString + ".png"
        let imageURL = attachmentsDir.appendingPathComponent(imageName)
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: imageURL)
            
            // 在 Markdown 中插入图片引用
            let imageMarkdown = "\n![Image](\(imageURL.path))\n"
            content += imageMarkdown
        }
    }
}

struct NewReviewSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trade.closeTime, ascending: false)],
        animation: .default)
    private var trades: FetchedResults<Trade>
    
    @State private var selectedTrade: Trade?
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("关联交易", selection: $selectedTrade) {
                    Text("无关联").tag(nil as Trade?)
                    ForEach(Array(trades), id: \.objectID) { trade in
                        Text("\(trade.symbol ?? "") - \(trade.closeTime ?? Date(), style: .date)")
                            .tag(trade as Trade?)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新建复盘")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createReview()
                    }
                }
            }
            .frame(width: 400, height: 200)
        }
    }
    
    private func createReview() {
        let review = Review(context: viewContext)
        review.id = UUID()
        review.createdAt = Date()
        review.updatedAt = Date()
        review.contentMarkdown = ""
        review.tags = []
        review.trade = selectedTrade
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("创建复盘失败: \(error)")
        }
    }
}

#Preview {
    ReviewEditorRootView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

