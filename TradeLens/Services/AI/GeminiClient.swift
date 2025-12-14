//
//  GeminiClient.swift
//  TradeLens
//
//  Created by TradeLens Team
//

import Foundation

// MARK: - Request Models

struct GeminiTradeSummaryRequest: Encodable {
    let model: String
    let contents: [Content]
    
    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }
    
    struct Part: Encodable {
        let text: String
    }
}

// MARK: - Response Models

struct GeminiTradeSummaryResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case requestFailed(Error)
    case badStatus(code: Int, message: String?)
    case decodeFailed
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .missingAPIKey:
            return "未配置 API Key，请在设置中配置"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .badStatus(let code, let message):
            return "服务器错误 (\(code)): \(message ?? "未知错误")"
        case .decodeFailed:
            return "响应解析失败"
        case .emptyResponse:
            return "收到空响应"
        }
    }
}

// MARK: - Gemini Client

final class GeminiClient {
    private let session: URLSession
    private let apiKeyProvider: () -> String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let defaultModel = "gemini-2.5-flash-preview-09-2025"
    
    init(session: URLSession = .shared,
         apiKeyProvider: @escaping () -> String?) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }
    
    func send(
        request: GeminiTradeSummaryRequest,
        model: String? = nil,
        maxRetries: Int = 3
    ) async throws -> GeminiTradeSummaryResponse {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let modelName = model ?? defaultModel
        let endpoint = "\(baseURL)/\(modelName):generateContent"
        
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw AIError.invalidURL
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw AIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60.0
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AIError.requestFailed(error)
        }
        
        // 指数退避重试机制
        var attempt = 0
        var delay: TimeInterval = 1.0
        
        while true {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.requestFailed(NSError(domain: "NoHTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 HTTP 响应"]))
                }
                
                // 成功响应
                if (200..<300).contains(httpResponse.statusCode) {
                    do {
                        let decoded = try JSONDecoder().decode(GeminiTradeSummaryResponse.self, from: data)
                        return decoded
                    } catch {
                        // 尝试解析错误信息
                        if let errorMessage = String(data: data, encoding: .utf8) {
                            print("解码失败，响应内容: \(errorMessage)")
                        }
                        throw AIError.decodeFailed
                    }
                }
                
                // 需要重试的状态码
                let shouldRetry = httpResponse.statusCode == 429 || (500..<600).contains(httpResponse.statusCode)
                
                if shouldRetry && attempt < maxRetries {
                    attempt += 1
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    print("请求失败 (状态码: \(httpResponse.statusCode))，\(backoffDelay) 秒后重试 (尝试 \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    delay = backoffDelay
                    continue
                }
                
                // 不可重试的错误或重试次数用尽
                let errorMessage = String(data: data, encoding: .utf8)
                throw AIError.badStatus(code: httpResponse.statusCode, message: errorMessage)
                
            } catch let error as AIError {
                // 如果是我们定义的错误类型，直接抛出
                throw error
            } catch {
                // 网络错误或其他错误
                if attempt < maxRetries {
                    attempt += 1
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    print("请求失败: \(error.localizedDescription)，\(backoffDelay) 秒后重试 (尝试 \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    delay = backoffDelay
                    continue
                } else {
                    throw AIError.requestFailed(error)
                }
            }
        }
    }
}

