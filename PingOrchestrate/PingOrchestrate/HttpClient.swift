//
//  HttpClient.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger

/// `HttpClient` is responsible for handling HTTP requests and logging the details of those requests and responses.
public final class HttpClient {
    var session: URLSession
    
    /// Initializes a new instance of `HttpClient`.
    /// - Parameter session: The URLSession instance to be used for HTTP requests. Defaults to a session with `RedirectPreventer` delegate.
    public init(session: URLSession = URLSession(configuration: URLSessionConfiguration.default,
                                                 delegate: RedirectPreventer(), delegateQueue: nil)) {
        self.session = session
    }
    
    /// Sets the timeout interval for HTTP requests.
    /// - Parameter timeoutInterval: The timeout interval in seconds.
    public func setTimeoutInterval(timeoutInterval: TimeInterval) {
        self.session.configuration.timeoutIntervalForRequest = timeoutInterval
        self.session.configuration.timeoutIntervalForResource = timeoutInterval
    }
    
    /// Logs the details of an HTTP request.
    /// - Parameter request: The URLRequest to be logged.
    public func logRequest(request: URLRequest?) {
        if request != nil {
            var log = "⬆\n"
            log += "Request URL: \(request?.url?.absoluteString ?? "")\n"
            log += "Request Method: \(request?.httpMethod ?? "")\n"
            if let headers = request?.allHTTPHeaderFields {
                log += "Request Headers: \(headers)\n"
            }
            if let bodyData = request?.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
                log += "Request Body: \(bodyString)\n"
            }
            LogManager.standard.d(log)
        }
    }
    
    // Logs the details of an HTTP response.
    /// - Parameter responseData: The data returned by the server.
    /// - Parameter response: The URLResponse object containing the response metadata.
    func logResponse(responseData: Data?, response: URLResponse?) {
        var log = "⬇\n"
        if let httpResponse = response as? HTTPURLResponse {
            log += "Response Status Code: \(httpResponse.statusCode)\n"
            log += "Response Headers: \(httpResponse.allHeaderFields)\n"
            log += "Response Value: \(httpResponse.debugDescription)\n"
        }
        
        if let data =  responseData, let dataString = String(data: data, encoding: .utf8) {
            log += "Response Data: \(dataString)"
        }
        LogManager.standard.d(log)
    }
    
    /// Sends an HTTP request and returns the response data and metadata.
    /// - Parameter request: The URLRequest to be sent.
    /// - Throws: An error if the request fails.
    /// - Returns: A tuple containing the response data and metadata.
    func sendRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        logRequest(request: request)
        let (data, response) = try await session.data(for: request)
        logResponse(responseData: data, response: response)
        return (data, response)
    }
    
    /// Sends an HTTP request and returns the response data and metadata.
    /// - Parameter request: The Request object to be sent.
    /// - Throws: An error if the request fails.
    /// - Returns: A tuple containing the response data and metadata.
    public func sendRequest(request: Request) async throws -> (Data, URLResponse) {
        return try await sendRequest(request:  request.urlRequest)
    }
    
}


/// RedirectPreventer` is a delegate class that prevents HTTP redirects during URL sessions.
/// This class conforms to `URLSessionDelegate` and `URLSessionTaskDelegate` to handle the redirection logic.
/// It ensures that any HTTP redirection responses are not followed by the `URLSession`.
public final class RedirectPreventer: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    /// Called when the session receives a redirection response.
    /// This method prevents the redirection by passing `nil` to the `completionHandler`.
    /// - Parameters:
    ///   - session: The session containing the task that received a redirect.
    ///   - task: The task whose request resulted in a redirect.
    ///   - response: The response that caused the redirect.
    ///   - request: A URL request object filled out with the new location.
    ///   - completionHandler: A closure to call with the URL request to allow the redirection, or `nil` to prevent it.
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Prevent the redirect by passing nil to the completionHandler
        completionHandler(nil)
    }
}
