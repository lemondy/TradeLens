//
//  SecurityService.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import Foundation
import Security

final class SecurityService {
    static let shared = SecurityService()
    
    private let apiKeyService = "com.tradelens.apikey"
    private let account = "gemini_api_key"
    
    private init() {}
    
    // MARK: - API Key Management
    
    func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // 先删除旧的
        SecItemDelete(query as CFDictionary)
        
        // 添加新的
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("保存 API Key 失败: \(status)")
        }
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
    
    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Data Encryption (Future)
    
    // 未来可以添加敏感数据的加密功能
    // 例如：交易金额、AI 分析结果等
}

