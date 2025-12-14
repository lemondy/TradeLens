//
//  PersistenceController.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建示例数据
        let sampleTrade = Trade(context: viewContext)
        sampleTrade.id = UUID()
        sampleTrade.symbol = "BTCUSDT"
        sampleTrade.side = "long"
        sampleTrade.openTime = Date().addingTimeInterval(-86400)
        sampleTrade.closeTime = Date()
        sampleTrade.openPrice = 50000
        sampleTrade.closePrice = 51000
        sampleTrade.leverage = 10
        sampleTrade.positionSize = 0.1
        sampleTrade.profitAmount = 100
        sampleTrade.profitRate = 0.02
        sampleTrade.status = "win"
        sampleTrade.source = "manual"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TradeLens")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
    }
}

