//
//  TradeLensApp.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI

@main
struct TradeLensApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .commands {
            CommandMenu("交易") {
                Button("新建交易") {
                    NotificationCenter.default.post(name: .newTradeShortcut, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            
            CommandMenu("编辑") {
                Button("粘贴图片") {
                    NotificationCenter.default.post(name: .pasteImageShortcut, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}

extension Notification.Name {
    static let newTradeShortcut = Notification.Name("TradeLens.NewTradeShortcut")
    static let pasteImageShortcut = Notification.Name("TradeLens.PasteImageShortcut")
}

