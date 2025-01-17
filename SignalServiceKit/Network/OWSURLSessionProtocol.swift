//
// Copyright 2022 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

// MARK: - HTTPMethod

public enum HTTPMethod: UInt {
    case get
    case post
    case put
    case head
    case patch
    case delete

    public var methodName: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .head:
            return "HEAD"
        case .patch:
            return "PATCH"
        case .delete:
            return "DELETE"
        }
    }

    public static func method(for method: String?) throws -> HTTPMethod {
        switch method {
        case "GET":
            return .get
        case "POST":
            return .post
        case "PUT":
            return .put
        case "HEAD":
            return .head
        case "PATCH":
            return .patch
        case "DELETE":
            return .delete
        default:
            throw OWSAssertionError("Unknown method: \(String(describing: method))")
        }
    }
}

extension HTTPMethod: CustomStringConvertible {
    public var description: String { methodName }
}

// MARK: - OWSUrlDownloadResponse

public struct OWSUrlDownloadResponse {
    public let task: URLSessionTask
    public let httpUrlResponse: HTTPURLResponse
    public let downloadUrl: URL

    public var statusCode: Int {
        httpUrlResponse.statusCode
    }

    public var allHeaderFields: [AnyHashable: Any] {
        httpUrlResponse.allHeaderFields
    }
}

// MARK: - OWSUrlFrontingInfo

struct OWSUrlFrontingInfo {
    public let frontingURLWithoutPathPrefix: URL
    public let frontingURLWithPathPrefix: URL
    public let unfrontedBaseUrl: URL

    func isFrontedUrl(_ urlString: String) -> Bool {
        urlString.lowercased().hasPrefix(frontingURLWithoutPathPrefix.absoluteString)
    }
}

// MARK: - OWSURLSession

// OWSURLSession is typically used for a single REST request.
//
// TODO: If we use OWSURLSession more, we'll need to add support for more features, e.g.:
//
// * Download tasks to memory.
public protocol OWSURLSessionProtocol: AnyObject {

    typealias ProgressBlock = (URLSessionTask, Progress) -> Void

    var endpoint: OWSURLSessionEndpoint { get }

    var failOnError: Bool { get set }
    // By default OWSURLSession treats 4xx and 5xx responses as errors.
    var require2xxOr3xx: Bool { get set }
    var allowRedirects: Bool { get set }

    var customRedirectHandler: ((URLRequest) -> URLRequest?)? { get set }

    static var defaultSecurityPolicy: HttpSecurityPolicy { get }
    static var signalServiceSecurityPolicy: HttpSecurityPolicy { get }
    static var defaultConfigurationWithCaching: URLSessionConfiguration { get }
    static var defaultConfigurationWithoutCaching: URLSessionConfiguration { get }

    static var userAgentHeaderKey: String { get }
    static var userAgentHeaderValueSignalIos: String { get }
    static var acceptLanguageHeaderKey: String { get }
    static var acceptLanguageHeaderValue: String { get }

    // MARK: Initializer

    init(
        endpoint: OWSURLSessionEndpoint,
        configuration: URLSessionConfiguration,
        maxResponseSize: Int?,
        canUseSignalProxy: Bool
    )

    // MARK: Tasks

    func promiseForTSRequest(_ rawRequest: TSRequest) -> Promise<HTTPResponse>

    func uploadTaskPromise(
        request: URLRequest,
        data requestData: Data,
        progress progressBlock: ProgressBlock?
    ) -> Promise<HTTPResponse>

    func uploadTaskPromise(
        request: URLRequest,
        fileUrl: URL,
        ignoreAppExpiry: Bool,
        progress progressBlock: ProgressBlock?
    ) -> Promise<HTTPResponse>

    func dataTaskPromise(
        request: URLRequest,
        ignoreAppExpiry: Bool
    ) -> Promise<HTTPResponse>

    func downloadTaskPromise(
        requestUrl: URL,
        resumeData: Data,
        progress progressBlock: ProgressBlock?
    ) -> Promise<OWSUrlDownloadResponse>

    func downloadTaskPromise(
        request: URLRequest,
        progress progressBlock: ProgressBlock?
    ) -> Promise<OWSUrlDownloadResponse>

    func webSocketTask(
        requestUrl: URL,
        didOpenBlock: @escaping (String?) -> Void,
        didCloseBlock: @escaping (Error) -> Void
    ) -> URLSessionWebSocketTask
}

extension OWSURLSessionProtocol {
    var unfrontedBaseUrl: URL? {
        endpoint.frontingInfo?.unfrontedBaseUrl ?? endpoint.baseUrl
    }

    // MARK: Convenience Methods

    init(
        endpoint: OWSURLSessionEndpoint,
        configuration: URLSessionConfiguration,
        maxResponseSize: Int? = nil,
        canUseSignalProxy: Bool = false
    ) {
        self.init(
            endpoint: endpoint,
            configuration: configuration,
            maxResponseSize: maxResponseSize,
            canUseSignalProxy: canUseSignalProxy
        )
    }
}

// MARK: -

public extension OWSURLSessionProtocol {

    // MARK: - Upload Tasks Convenience

    func uploadTaskPromise(
        _ urlString: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        data requestData: Data,
        progress progressBlock: ProgressBlock? = nil
    ) -> Promise<HTTPResponse> {
        firstly(on: DispatchQueue.global()) { () -> Promise<HTTPResponse> in
            let request = try self.endpoint.buildRequest(urlString, method: method, headers: headers, body: requestData)
            return self.uploadTaskPromise(request: request, data: requestData, progress: progressBlock)
        }
    }

    func uploadTaskPromise(
        _ urlString: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        fileUrl: URL,
        progress progressBlock: ProgressBlock? = nil
    ) -> Promise<HTTPResponse> {
        firstly(on: DispatchQueue.global()) { () -> Promise<HTTPResponse> in
            let request = try self.endpoint.buildRequest(urlString, method: method, headers: headers)
            return self.uploadTaskPromise(request: request, fileUrl: fileUrl, ignoreAppExpiry: false, progress: progressBlock)
        }
    }

    // MARK: - Data Tasks Convenience

    func dataTaskPromise(
        on scheduler: Scheduler = DispatchQueue.global(),
        _ urlString: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        body: Data? = nil,
        ignoreAppExpiry: Bool = false
    ) -> Promise<HTTPResponse> {
        firstly(on: scheduler) { () -> Promise<HTTPResponse> in
            let request = try self.endpoint.buildRequest(urlString, method: method, headers: headers, body: body)
            return self.dataTaskPromise(request: request, ignoreAppExpiry: ignoreAppExpiry)
        }
    }

    // MARK: - Download Tasks Convenience

    func downloadTaskPromise(
        on scheduler: Scheduler = DispatchQueue.global(),
        _ urlString: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        body: Data? = nil,
        progress progressBlock: ProgressBlock? = nil
    ) -> Promise<OWSUrlDownloadResponse> {
        firstly(on: scheduler) { () -> Promise<OWSUrlDownloadResponse> in
            let request = try self.endpoint.buildRequest(urlString, method: method, headers: headers, body: body)
            return self.downloadTaskPromise(request: request, progress: progressBlock)
        }
    }
}

// MARK: - MultiPart Task

extension OWSURLSessionProtocol {

    public func multiPartUploadTaskPromise(
        request: URLRequest,
        fileUrl inputFileURL: URL,
        name: String,
        fileName: String,
        mimeType: String,
        textParts textPartsDictionary: OrderedDictionary<String, String>,
        ignoreAppExpiry: Bool = false,
        progress progressBlock: ProgressBlock? = nil
    ) -> Promise<HTTPResponse> {
        do {
            let multipartBodyFileURL = OWSFileSystem.temporaryFileUrl(isAvailableWhileDeviceLocked: true)
            let boundary = OWSMultipartBody.createMultipartFormBoundary()
            // Order of form parts matters.
            let textParts = textPartsDictionary.map { (key, value) in
                OWSMultipartTextPart(key: key, value: value)
            }
            try OWSMultipartBody.write(inputFile: inputFileURL,
                                       outputFile: multipartBodyFileURL,
                                       name: name,
                                       fileName: fileName,
                                       mimeType: mimeType,
                                       boundary: boundary,
                                       textParts: textParts)
            guard let bodyFileSize = OWSFileSystem.fileSize(of: multipartBodyFileURL) else {
                return Promise(error: OWSAssertionError("Missing bodyFileSize."))
            }

            var request = request
            request.httpMethod = HTTPMethod.post.methodName
            request.setValue(Self.userAgentHeaderValueSignalIos, forHTTPHeaderField: Self.userAgentHeaderKey)
            request.setValue(Self.acceptLanguageHeaderValue, forHTTPHeaderField: Self.acceptLanguageHeaderKey)
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(String(format: "%llu", bodyFileSize.uint64Value), forHTTPHeaderField: "Content-Length")

            return firstly {
                uploadTaskPromise(request: request,
                                  fileUrl: multipartBodyFileURL,
                                  ignoreAppExpiry: ignoreAppExpiry,
                                  progress: progressBlock)
            }.ensure(on: DispatchQueue.global()) {
                do {
                    try OWSFileSystem.deleteFileIfExists(url: multipartBodyFileURL)
                } catch {
                    owsFailDebug("Error: \(error)")
                }
            }
        } catch {
            owsFailDebugUnlessNetworkFailure(error)
            return Promise(error: error)
        }
    }
}
