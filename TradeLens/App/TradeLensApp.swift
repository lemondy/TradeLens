//
//  TradeLensApp.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import SwiftUI

enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "白天"
        case .dark:
            return "夜间"
        case .system:
            return "跟随系统"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

@main
struct TradeLensApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("themeMode") private var themeModeString: String = ThemeMode.system.rawValue
    
    private var colorScheme: ColorScheme? {
        ThemeMode(rawValue: themeModeString)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(colorScheme)
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

