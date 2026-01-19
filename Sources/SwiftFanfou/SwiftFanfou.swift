//
//  SwiftFanfou.swift
//  SwiftFanfou
//
//  Created by Maundy Liu on 2026/1/18.
//

import Foundation

public final class SwiftFanfou {
    public let credential: OAuthSwiftCredential

    public init(consumerKey: String, consumerSecret: String, oauthToken: String = "", oauthTokenSecret: String = "") {
        credential = OAuthSwiftCredential(consumerKey: consumerKey, consumerSecret: consumerSecret, oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret)
    }

    public func xAuth(userName: String, password: String, completion: @escaping (Result<(token: String, secret: String), Error>) -> Void) {
        request("https://fanfou.com/oauth/access_token", method: "POST", parameters: ["x_auth_username": userName, "x_auth_password": password, "x_auth_mode": "client_auth"]) { result in
            switch result {
            case .success(let data):
                guard let string = String(data: data, encoding: .utf8) else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }
                var components = URLComponents()
                components.query = string
                var dict: [String: String] = [:]
                components.queryItems?.forEach { item in
                    dict[item.name] = item.value ?? ""
                }
                guard let token = dict["oauth_token"], let tokenSecret = dict["oauth_token_secret"] else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])))
                    return
                }
                self.credential.oauthToken = token
                self.credential.oauthTokenSecret = tokenSecret
                completion(.success((token: token, secret: tokenSecret)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func requestToken(callbackURL: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = "https://fanfou.com/oauth/request_token"

        request(url, method: "POST") { result in
            switch result {
            case .success(let data):
                guard let string = String(data: data, encoding: .utf8) else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                var components = URLComponents()
                components.query = string
                var dict: [String: String] = [:]
                components.queryItems?.forEach { item in
                    dict[item.name] = item.value ?? ""
                }

                guard let token = dict["oauth_token"], let tokenSecret = dict["oauth_token_secret"] else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing request token"])))
                    return
                }

                self.credential.requestToken = token
                self.credential.requestTokenSecret = tokenSecret
                completion(.success(URL(string: "https://fanfou.com/oauth/authorize?oauth_token=\(token)&oauth_callback=\(callbackURL)")!))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func accessToken(completion: @escaping (Result<(token: String, secret: String), Error>) -> Void) {
        let url = "https://fanfou.com/oauth/access_token"

        let originalToken = credential.oauthToken
        let originalSecret = credential.oauthTokenSecret
        credential.oauthToken = credential.requestToken
        credential.oauthTokenSecret = credential.requestTokenSecret

        request(url, method: "POST") { result in
            self.credential.oauthToken = originalToken
            self.credential.oauthTokenSecret = originalSecret

            switch result {
            case .success(let data):
                guard let string = String(data: data, encoding: .utf8) else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                var components = URLComponents()
                components.query = string
                var dict: [String: String] = [:]
                components.queryItems?.forEach { item in
                    dict[item.name] = item.value ?? ""
                }

                guard let token = dict["oauth_token"], let tokenSecret = dict["oauth_token_secret"] else {
                    completion(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])))
                    return
                }

                self.credential.oauthToken = token
                self.credential.oauthTokenSecret = tokenSecret

                self.credential.requestToken = ""
                self.credential.requestTokenSecret = ""

                completion(.success((token: token, secret: tokenSecret)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }


    public func request(_ url: URLConvertible, method: String, parameters: [String: Any] = [:], body: Data? = nil, completionHandler: OAuthSwiftHTTPRequest.CompletionHandler?) {
        guard let request = makeRequest(url, method: method, parameters: parameters, body: body) else {
            completionHandler?(.failure(NSError(domain: "SwiftFanfou", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        request.start(completionHandler: completionHandler)
    }

    // use "image" as name when request "/account/update_profile_image"
    public func request(_ url: URLConvertible, parameters: [String: Any], image: Data, name: String = "photo", completionHandler: OAuthSwiftHTTPRequest.CompletionHandler?) {
        let multiparts = [OAuthSwiftMultipartData(name: name, data: image, fileName: "file", mimeType: "image/jpeg")]
        let boundary = "AS-boundary-\(arc4random())-\(arc4random())"
        let headers = ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        let body = multiDataFromObject(parameters, multiparts: multiparts, boundary: boundary)
        let request = makeRequest(url, method: "POST", headers: headers, body: body)
        request?.start(completionHandler: completionHandler)
    }

    public func makeRequest(_ url: URLConvertible, method: String, parameters: [String: Any] = [:], headers: [String: String]? = nil, body: Data? = nil) -> OAuthSwiftHTTPRequest? {
        guard let url = url.url else { return nil }
        let request = OAuthSwiftHTTPRequest(url: url, method: method, parameters: parameters, httpBody: body, headers: headers ?? [:])
        request.config.updateRequest(credential: credential)
        return request
    }

    private func multiDataFromObject(_ object: [String: Any], multiparts: [OAuthSwiftMultipartData], boundary: String) -> Data {
        var data = Data()
        let prefixData = "--\(boundary)\r\n".data(using: .utf8)!

        for (key, value) in object {
            guard let valueData = "\(value)".data(using: .utf8) else { continue }
            data.append(prefixData)
            let multipartData = OAuthSwiftMultipartData(name: key, data: valueData, fileName: nil, mimeType: nil)
            data.append(multipartData, encoding: .utf8)
        }

        for multipart in multiparts {
            data.append(prefixData)
            data.append(multipart, encoding: .utf8)
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}

public final class OAuthSwiftHTTPRequest {
    public typealias CompletionHandler = (Result<Data, Error>) -> Void

    public var config: Config
    private var request: URLRequest?
    private var task: URLSessionTask?
    
    // 创建一个禁用 cookie 的 URLSession
    private static let noCookieSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    public init(url: URL, method: String, parameters: [String: Any] = [:], httpBody: Data? = nil, headers: [String: String] = [:]) {
        self.config = Config(url: url, httpMethod: method, httpBody: httpBody, headers: headers, parameters: parameters)
    }

    public func start(completionHandler completion: CompletionHandler?) {
        guard request == nil else { return }

        do {
            self.request = try makeRequest()
        } catch {
            completion?(.failure(error))
            return
        }

        let usedRequest = self.request!
        // 使用禁用 cookie 的 session
        task = Self.noCookieSession.dataTask(with: usedRequest) { data, resp, error in
            if let error = error {
                completion?(.failure(error))
                return
            }

            guard let response = resp as? HTTPURLResponse,
                  let responseData = data,
                  response.statusCode < 400 else {
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Request failed"
                completion?(.failure(NSError(domain: "SwiftFanfou", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }

            completion?(.success(responseData))
        }
        task?.resume()
    }

    private func makeRequest() throws -> URLRequest {
        var request = config.urlRequest

        if request.httpBody != nil {
            return request
        }

        let finalParameters = config.parameters.filter { !$0.key.hasPrefix("oauth_") }
        guard !finalParameters.isEmpty else { return request }

        let charset = config.dataEncoding.charset
        let headers = request.allHTTPHeaderFields ?? [:]

        if ["GET", "HEAD", "DELETE"].contains(request.httpMethod) {
            let queryString = finalParameters.urlEncodedQuery
            request.url = request.url!.urlByAppending(queryString: queryString)
            if headers["Content-Type"] == nil {
                request.setValue("application/x-www-form-urlencoded; charset=\(charset)", forHTTPHeaderField: "Content-Type")
            }
        } else if let contentType = headers["Content-Type"], contentType.contains("application/json") {
            let jsonData = try JSONSerialization.data(withJSONObject: finalParameters, options: [])
            request.setValue("application/json; charset=\(charset)", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
        } else {
            request.setValue("application/x-www-form-urlencoded; charset=\(charset)", forHTTPHeaderField: "Content-Type")
            request.httpBody = finalParameters.urlEncodedQuery.data(using: config.dataEncoding)
        }

        return request
    }
}

extension OAuthSwiftHTTPRequest {
    public struct Config {
        public var urlRequest: URLRequest
        public var parameters: [String: Any]
        public let dataEncoding: String.Encoding

        public init(url: URL, httpMethod: String, httpBody: Data? = nil, headers: [String: String] = [:], parameters: [String: Any], dataEncoding: String.Encoding = .utf8) {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = httpMethod
            urlRequest.httpBody = httpBody
            urlRequest.allHTTPHeaderFields = headers

            self.urlRequest = urlRequest
            self.parameters = parameters
            self.dataEncoding = dataEncoding
        }

        public mutating func updateRequest(credential: OAuthSwiftCredential) {
            let method = urlRequest.httpMethod ?? "GET"
            let url = urlRequest.url!
            let headers = urlRequest.allHTTPHeaderFields ?? [:]

            var signatureUrl = url
            var signatureParameters = parameters

            if ["POST", "PUT", "PATCH"].contains(method) {
                if let contentType = headers["Content-Type"]?.lowercased(), contentType.contains("application/json") {
                    signatureParameters = [:]
                }
            }

            var queryStringParameters = [String: Any]()
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = urlComponents?.queryItems {
                for queryItem in queryItems {
                    queryStringParameters[queryItem.name] = queryItem.value?.safeStringByRemovingPercentEncoding ?? ""
                }
            }

            if !queryStringParameters.isEmpty {
                urlComponents?.query = nil
                signatureUrl = urlComponents?.url ?? url
            }

            signatureParameters = signatureParameters.join(queryStringParameters)

            let requestHeaders = credential.makeHeaders(signatureUrl, method: method, parameters: signatureParameters)
            urlRequest.allHTTPHeaderFields = requestHeaders.join(headers)
        }
    }
}

public final class OAuthSwiftCredential {
    public let consumerKey: String
    public let consumerSecret: String
    public var oauthToken = ""
    public var oauthTokenSecret = ""
    public var requestToken: String = ""
    public var requestTokenSecret: String = ""

    public init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.oauthToken = oauthToken
        self.oauthTokenSecret = oauthTokenSecret
    }

    public func makeHeaders(_ url: URL, method: String, parameters: [String: Any]) -> [String: String] {
        let timestamp = String(Int64(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.prefix(8).description

        let authParams = authorizationParametersWithSignature(method: method, url: url, parameters: parameters, timestamp: timestamp, nonce: nonce)

        let components = authParams.urlEncodedQuery.components(separatedBy: "&").sorted()
        let headerComponents = components.compactMap { component -> String? in
            let parts = component.components(separatedBy: "=")
            guard parts.count == 2 else { return nil }
            return "\(parts[0])=\"\(parts[1])\""
        }

        return ["Authorization": "OAuth " + headerComponents.joined(separator: ", ")]
    }

    private func authorizationParametersWithSignature(method: String, url: URL, parameters: [String: Any], timestamp: String, nonce: String) -> [String: Any] {
        var authParams: [String: Any] = [
            "oauth_version": "1.0",
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_consumer_key": consumerKey,
            "oauth_timestamp": timestamp,
            "oauth_nonce": nonce
        ]

        if !oauthToken.isEmpty {
            authParams["oauth_token"] = oauthToken
        }

        for (key, value) in parameters where key.hasPrefix("oauth_") {
            authParams[key] = value
        }

        let combinedParameters = authParams.join(parameters)
        authParams["oauth_signature"] = signature(method: method, url: url, parameters: combinedParameters)

        return authParams
    }

    private func signature(method: String, url: URL, parameters: [String: Any]) -> String {
        let signingKey = "\(consumerSecret.urlEncoded)&\(oauthTokenSecret.urlEncoded)"

        let parameterComponents = parameters.urlEncodedQuery.components(separatedBy: "&").sorted { a, b in
            let p0 = a.components(separatedBy: "=")
            let p1 = b.components(separatedBy: "=")
            if p0.first == p1.first { return (p0.last ?? "") < (p1.last ?? "") }
            return (p0.first ?? "") < (p1.first ?? "")
        }

        let parameterString = parameterComponents.joined(separator: "&")
        var encodedURL = url.absoluteString.urlEncoded

        // handle fanfou bug: HTTPS -> HTTP
        if url.absoluteString.hasPrefix("https") {
            encodedURL = ("http" + url.absoluteString.dropFirst(5)).urlEncoded
        }

        let signatureBaseString = "\(method)&\(encodedURL)&\(parameterString.urlEncoded)"

        let key = signingKey.data(using: .utf8)!
        let message = signatureBaseString.data(using: .utf8)!
        let sha1 = HMAC.sha1(key: key, message: message)!

        return sha1.base64EncodedString()
    }
}

struct HMAC {
    static func sha1(key: Data, message: Data) -> Data? {
        let blockSize = 64
        var key = key.bytes
        let message = message.bytes

        if key.count > blockSize {
            key = SHA1(key).calculate()
        } else if key.count < blockSize {
            key += [UInt8](repeating: 0, count: blockSize - key.count)
        }

        var ipad = [UInt8](repeating: 0x36, count: blockSize)
        for idx in key.indices {
            ipad[idx] = key[idx] ^ ipad[idx]
        }

        var opad = [UInt8](repeating: 0x5c, count: blockSize)
        for idx in key.indices {
            opad[idx] = key[idx] ^ opad[idx]
        }

        let ipadAndMessageHash = SHA1(ipad + message).calculate()
        let mac = SHA1(opad + ipadAndMessageHash).calculate()

        return Data(mac)
    }
}

struct SHA1 {
    let message: [UInt8]

    init(_ message: Data) {
        self.message = message.bytes
    }

    init(_ message: [UInt8]) {
        self.message = message
    }

    func calculate() -> [UInt8] {
        var tmpMessage = message
        tmpMessage.append(0x80)

        var msgLength = tmpMessage.count
        var counter = 0
        while msgLength % 64 != 56 {
            counter += 1
            msgLength += 1
        }
        tmpMessage += [UInt8](repeating: 0, count: counter)
        tmpMessage += withUnsafeBytes(of: message.count * 8) { bytes in
            [UInt8](bytes.reversed())
        }

        var hh: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

        for chunk in stride(from: 0, to: tmpMessage.count, by: 64) {
            var M = [UInt32](repeating: 0, count: 80)

            for x in 0..<16 {
                let start = chunk + (x * 4)
                M[x] = UInt32(bigEndian: tmpMessage[start..<start+4].toUInt32)
            }

            for x in 16..<80 {
                M[x] = rotateLeft(M[x-3] ^ M[x-8] ^ M[x-14] ^ M[x-16], n: 1)
            }

            var (A, B, C, D, E) = (hh[0], hh[1], hh[2], hh[3], hh[4])

            for j in 0..<80 {
                let (f, k): (UInt32, UInt32) = {
                    switch j {
                    case 0...19: return ((B & C) | ((~B) & D), 0x5A827999)
                    case 20...39: return (B ^ C ^ D, 0x6ED9EBA1)
                    case 40...59: return ((B & C) | (B & D) | (C & D), 0x8F1BBCDC)
                    default: return (B ^ C ^ D, 0xCA62C1D6)
                    }
                }()

                let temp = (rotateLeft(A, n: 5) &+ f &+ E &+ M[j] &+ k) & 0xffffffff
                (E, D, C, B, A) = (D, C, rotateLeft(B, n: 30), A, temp)
            }

            hh[0] = (hh[0] &+ A) & 0xffffffff
            hh[1] = (hh[1] &+ B) & 0xffffffff
            hh[2] = (hh[2] &+ C) & 0xffffffff
            hh[3] = (hh[3] &+ D) & 0xffffffff
            hh[4] = (hh[4] &+ E) & 0xffffffff
        }

        return hh.flatMap { item in
            let item = item.bigEndian
            return [UInt8(item & 0xff), UInt8((item >> 8) & 0xff), UInt8((item >> 16) & 0xff), UInt8((item >> 24) & 0xff)]
        }
    }

    private func rotateLeft(_ v: UInt32, n: UInt32) -> UInt32 {
        return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
    }
}

public struct OAuthSwiftMultipartData {
    public let name: String
    public let data: Data
    public let fileName: String?
    public let mimeType: String?
    
    public init(name: String, data: Data, fileName: String?, mimeType: String?) {
        self.name = name
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

public protocol URLConvertible {
    var string: String { get }
    var url: URL? { get }
}

extension Data {
    var bytes: [UInt8] { Array(self) }

    mutating func append(_ multipartData: OAuthSwiftMultipartData, encoding: String.Encoding) {
        var filenameClause = ""
        if let filename = multipartData.fileName {
            filenameClause = "; filename=\"\(filename)\""
        }

        append("Content-Disposition: form-data; name=\"\(multipartData.name)\"\(filenameClause)\r\n", using: encoding)

        if let mimeType = multipartData.mimeType {
            append("Content-Type: \(mimeType)\r\n", using: encoding)
        }

        append("\r\n", using: encoding)
        append(multipartData.data)
        append("\r\n", using: encoding)
    }

    private mutating func append(_ string: String, using encoding: String.Encoding) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}

extension String.Encoding {
    var charset: String {
        CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(rawValue))! as String
    }
}

extension String: URLConvertible {
    public var string: String { self }
    public var url: URL? { URL(string: self) }

    var urlEncoded: String {
        let customAllowedSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return addingPercentEncoding(withAllowedCharacters: customAllowedSet)!
    }

    var safeStringByRemovingPercentEncoding: String {
        removingPercentEncoding ?? self
    }
}

extension URL: URLConvertible {
    public var string: String { absoluteString }
    public var url: URL? { self }

    func urlByAppending(queryString: String) -> URL {
        guard !queryString.isEmpty else { return self }
        
        var urlString = absoluteString
        if urlString.hasSuffix("?") {
            urlString.removeLast()
        }

        let separator = urlString.contains("?") ? "&" : "?"
        return URL(string: urlString + separator + queryString)!
    }
}

extension Dictionary {
    func join(_ other: Dictionary) -> Dictionary {
        var result = self
        for (key, value) in other {
            result[key] = value
        }
        return result
    }

    var urlEncodedQuery: String {
        map { "\("\($0.key)".urlEncoded)=\("\($0.value)".urlEncoded)" }.joined(separator: "&")
    }
}

extension Collection where Element == UInt8, Index == Int {
    var toUInt32: UInt32 {
        assert(count > 3)
        var val: UInt32 = 0
        val |= count > 3 ? UInt32(self[startIndex + 3]) << 24 : 0
        val |= count > 2 ? UInt32(self[startIndex + 2]) << 16 : 0
        val |= count > 1 ? UInt32(self[startIndex + 1]) << 8 : 0
        val |= count > 0 ? UInt32(self[startIndex]) : 0
        return val
    }
}