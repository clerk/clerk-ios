#if !os(watchOS)
import Foundation
@preconcurrency import JavaScriptCore
import Security

final class NativeHost: @unchecked Sendable {
  weak var runtime: JSRuntime?
  private let tokenCache: ClerkJSTokenCache
  private let session: URLSession
  private var nextTimerID: UInt64 = 1
  private var nextFetchID: UInt64 = 1
  private var nextCallbackID: UInt64 = 1
  private var timers: [UInt64: DispatchWorkItem] = [:]
  private var fetches: [UInt64: InFlightFetch] = [:]
  private var callbacks: [UInt64: JSValue] = [:]
  private(set) var lastClientJSON: Data?

  init(tokenCache: ClerkJSTokenCache) {
    self.tokenCache = tokenCache
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.httpCookieAcceptPolicy = .never
    configuration.urlCache = nil
    session = URLSession(configuration: configuration)
  }

  func install(on context: JSContext) {
    installBridges(on: context)
    context.evaluateScript(Self.polyfillSource)
  }

  func abortFetches(for callID: UInt64) {
    let ids = fetches.compactMap { $0.value.callID == callID ? $0.key : nil }
    for id in ids {
      abortFetch(id)
    }
  }

  func invalidate() {
    timers.values.forEach { $0.cancel() }
    timers.removeAll()
    callbacks.removeAll()
    for id in Array(fetches.keys) {
      abortFetch(id)
    }
    session.invalidateAndCancel()
  }

  private func retainCallback(_ callback: JSValue) -> UInt64 {
    let id = nextCallbackID
    nextCallbackID += 1
    callbacks[id] = callback
    return id
  }

  private func takeCallback(_ id: UInt64) -> JSValue? {
    callbacks.removeValue(forKey: id)
  }

  private func installBridges(on context: JSContext) {
    let parseURL: @convention(block) (String, String?) -> [String: String]? = { href, base in
      Self.parseURL(href, base: base)
    }
    context.setObject(parseURL, forKeyedSubscript: "__clerkNativeParseURL" as NSString)

    let atob: @convention(block) (String) -> String = { encoded in
      Self.atob(encoded)
    }
    context.setObject(atob, forKeyedSubscript: "__clerkNativeAtob" as NSString)

    let btoa: @convention(block) (String) -> String = { raw in
      Self.btoa(raw)
    }
    context.setObject(btoa, forKeyedSubscript: "__clerkNativeBtoa" as NSString)

    let random: @convention(block) (Int) -> [UInt8] = { count in
      Self.randomBytes(count)
    }
    context.setObject(random, forKeyedSubscript: "__clerkNativeRandom" as NSString)

    let setTimeout: @convention(block) (JSValue, Double) -> NSNumber = { [weak self] callback, delayMs in
      guard let self, let runtime else { return 0 }
      let id = nextTimerID
      nextTimerID += 1
      let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        timers[id] = nil
        callback.call(withArguments: [])
      }
      timers[id] = work
      runtime.queue.asyncAfter(deadline: .now() + max(0, delayMs / 1000), execute: work)
      return NSNumber(value: id)
    }
    context.setObject(setTimeout, forKeyedSubscript: "__clerkNativeSetTimeout" as NSString)

    let clearTimeout: @convention(block) (JSValue) -> Void = { [weak self] value in
      let id = UInt64(value.toUInt32())
      self?.timers.removeValue(forKey: id)?.cancel()
    }
    context.setObject(clearTimeout, forKeyedSubscript: "__clerkNativeClearTimeout" as NSString)

    let fetch: @convention(block) (String, JSValue) -> NSNumber = { [weak self] payload, callback in
      NSNumber(value: self?.startFetch(payload: payload, callback: callback) ?? 0)
    }
    context.setObject(fetch, forKeyedSubscript: "__clerkNativeFetch" as NSString)

    let abortFetch: @convention(block) (JSValue) -> Void = { [weak self] value in
      self?.abortFetch(UInt64(value.toUInt32()))
    }
    context.setObject(abortFetch, forKeyedSubscript: "__clerkNativeAbortFetch" as NSString)

    let getToken: @convention(block) (JSValue) -> Void = { [weak self] callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        let token = await self.tokenCache.getToken()
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull(), token])
        }
      }
    }
    context.setObject(getToken, forKeyedSubscript: "__clerkNativeGetTokenImpl" as NSString)

    let saveToken: @convention(block) (String, JSValue) -> Void = { [weak self] token, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        await self.tokenCache.saveToken(token)
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull()])
        }
      }
    }
    context.setObject(saveToken, forKeyedSubscript: "__clerkNativeSaveTokenImpl" as NSString)
  }

  private func startFetch(payload: String, callback: JSValue) -> UInt64 {
    let id = nextFetchID
    nextFetchID += 1
    let callID = runtime?.currentCallID
    guard let data = payload.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let urlString = object["url"] as? String,
          let url = URL(string: urlString),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme)
    else {
      callback.call(withArguments: ["Invalid HTTP URL", NSNull()])
      return id
    }

    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.httpShouldHandleCookies = false
    request.httpMethod = (object["method"] as? String) ?? "GET"
    if let headers = object["headers"] as? [String: String] {
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }
    if let body = object["body"] as? String {
      request.httpBody = body.data(using: .utf8)
    }

    let task = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self, let runtime else { return }
      runtime.queue.async {
        self.completeFetch(id, data: data, response: response, error: error)
      }
    }
    fetches[id] = InFlightFetch(callID: callID, task: task, callback: callback)
    task.resume()
    return id
  }

  private func completeFetch(_ id: UInt64, data: Data?, response: URLResponse?, error: Error?) {
    guard let inflight = fetches.removeValue(forKey: id) else { return }
    if let error {
      if (error as? URLError)?.code == .cancelled {
        inflight.callback.call(withArguments: ["The operation was aborted.", NSNull()])
      } else {
        inflight.callback.call(withArguments: [error.localizedDescription, NSNull()])
      }
      return
    }
    guard let http = response as? HTTPURLResponse else {
      inflight.callback.call(withArguments: ["Expected an HTTP response", NSNull()])
      return
    }
    if let data, let clientJSON = Self.clientJSON(fromFAPIBody: data) {
      lastClientJSON = clientJSON
    }
    var headers: [String: String] = [:]
    for (key, value) in http.allHeaderFields {
      headers[String(describing: key).lowercased()] = String(describing: value)
    }
    if let authorization = http.value(forHTTPHeaderField: "Authorization"), !authorization.isEmpty {
      headers["authorization"] = authorization
    }
    let payload: [String: Any] = [
      "status": http.statusCode,
      "statusText": HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
      "headers": headers,
      "body": String(data: data ?? Data(), encoding: .utf8) ?? "",
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: json, encoding: .utf8)
    else {
      inflight.callback.call(withArguments: ["Failed to encode response", NSNull()])
      return
    }
    inflight.callback.call(withArguments: [NSNull(), text])
  }

  private func abortFetch(_ id: UInt64) {
    guard let inflight = fetches.removeValue(forKey: id) else { return }
    inflight.task.cancel()
    inflight.callback.call(withArguments: ["The operation was aborted.", NSNull()])
  }

  private static func clientJSON(fromFAPIBody data: Data) -> Data? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    let inner = asClientJSON(object["client"]) ?? asClientJSON(object["response"]) ?? asClientJSON(object)
    guard let inner else {
      return nil
    }
    return try? JSONSerialization.data(withJSONObject: inner)
  }

  private static func asClientJSON(_ value: Any?) -> [String: Any]? {
    guard let object = value as? [String: Any], object["object"] as? String == "client" else {
      return nil
    }
    return object
  }

  private static func parseURL(_ href: String, base: String?) -> [String: String]? {
    let url: URL
    if let base, let baseURL = URL(string: base), let resolved = URL(string: href, relativeTo: baseURL) {
      url = resolved.absoluteURL
    } else if let parsed = URL(string: href), parsed.scheme != nil {
      url = parsed
    } else {
      return nil
    }
    let hostname = url.host ?? ""
    let port = url.port.map(String.init) ?? ""
    let host = port.isEmpty ? hostname : "\(hostname):\(port)"
    let scheme = url.scheme.map { "\($0):" } ?? ""
    var pathname = url.path
    if pathname.isEmpty {
      pathname = "/"
    }
    let search = url.query.map { "?\($0)" } ?? ""
    let hash = url.fragment.map { "#\($0)" } ?? ""
    return [
      "href": url.absoluteString,
      "protocol": scheme,
      "host": host,
      "hostname": hostname,
      "port": port,
      "pathname": pathname,
      "search": search,
      "hash": hash,
      "origin": "\(scheme)//\(host)",
    ]
  }

  private static func atob(_ encoded: String) -> String {
    guard let data = Data(base64Encoded: encoded) else { return "" }
    return String(data: data, encoding: .isoLatin1) ?? ""
  }

  private static func btoa(_ raw: String) -> String {
    (raw.data(using: .isoLatin1) ?? Data(raw.utf8)).base64EncodedString()
  }

  private static func randomBytes(_ count: Int) -> [UInt8] {
    let size = max(0, count)
    var bytes = [UInt8](repeating: 0, count: size)
    if size > 0 {
      _ = SecRandomCopyBytes(kSecRandomDefault, size, &bytes)
    }
    return bytes
  }

  private static let polyfillSource = """
    (function() {
      if (typeof console === 'undefined') {
        globalThis.console = { log: function(){}, warn: function(){}, error: function(){}, info: function(){}, debug: function(){} };
      }
      globalThis.self = globalThis;
      globalThis.navigator = { onLine: true, userAgent: 'ClerkKit/js-core' };

      function headersToObject(headers) {
        var out = {};
        headers.forEach(function(value, key) { out[key] = value; });
        return out;
      }

      function URLSearchParams(init) {
        this._pairs = [];
        if (!init) return;
        if (typeof init === 'string') {
          var text = init.charAt(0) === '?' ? init.slice(1) : init;
          if (!text) return;
          text.split('&').forEach(function(part) {
            if (!part) return;
            var eq = part.indexOf('=');
            var key = eq === -1 ? part : part.slice(0, eq);
            var value = eq === -1 ? '' : part.slice(eq + 1);
            this._pairs.push([decodeURIComponent(key.replace(/\\+/g, ' ')), decodeURIComponent(value.replace(/\\+/g, ' '))]);
          }, this);
        } else if (init && typeof init.forEach === 'function') {
          init.forEach(function(value, key) { this.append(key, value); }, this);
        } else if (Array.isArray(init)) {
          for (var i = 0; i < init.length; i++) this.append(init[i][0], init[i][1]);
        } else {
          for (var key in init) this.append(key, init[key]);
        }
      }
      URLSearchParams.prototype.append = function(key, value) {
        this._pairs.push([String(key), String(value)]);
      };
      URLSearchParams.prototype.set = function(key, value) {
        key = String(key);
        this._pairs = this._pairs.filter(function(pair) { return pair[0] !== key; });
        this.append(key, value);
      };
      URLSearchParams.prototype.get = function(key) {
        key = String(key);
        for (var i = 0; i < this._pairs.length; i++) {
          if (this._pairs[i][0] === key) return this._pairs[i][1];
        }
        return null;
      };
      URLSearchParams.prototype.has = function(key) {
        return this.get(key) !== null;
      };
      URLSearchParams.prototype.delete = function(key) {
        key = String(key);
        this._pairs = this._pairs.filter(function(pair) { return pair[0] !== key; });
      };
      URLSearchParams.prototype.forEach = function(cb, thisArg) {
        for (var i = 0; i < this._pairs.length; i++) cb.call(thisArg, this._pairs[i][1], this._pairs[i][0], this);
      };
      URLSearchParams.prototype.entries = function() { return this._pairs.slice(); };
      URLSearchParams.prototype.keys = function() { return this._pairs.map(function(pair) { return pair[0]; }); };
      URLSearchParams.prototype.values = function() { return this._pairs.map(function(pair) { return pair[1]; }); };
      URLSearchParams.prototype[Symbol.iterator] = function() { return this.entries()[Symbol.iterator](); };
      URLSearchParams.prototype.toString = function() {
        return this._pairs.map(function(pair) {
          return encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1]);
        }).join('&');
      };
      globalThis.URLSearchParams = URLSearchParams;

      function URL(url, base) {
        var parsed = __clerkNativeParseURL(String(url), base == null ? null : String(base));
        if (!parsed) throw new TypeError('Invalid URL');
        this.protocol = parsed.protocol;
        this.hostname = parsed.hostname;
        this.port = parsed.port;
        this.hash = parsed.hash;
        this.origin = parsed.origin;
        this.searchParams = new URLSearchParams(parsed.search);
        this.pathname = parsed.pathname;
      }
      Object.defineProperty(URL.prototype, 'pathname', {
        get: function() { return this._pathname; },
        set: function(value) {
          value = String(value);
          this._pathname = value.charAt(0) === '/' ? value : '/' + value;
        }
      });
      Object.defineProperty(URL.prototype, 'host', {
        get: function() { return this.port ? this.hostname + ':' + this.port : this.hostname; }
      });
      Object.defineProperty(URL.prototype, 'search', {
        get: function() {
          var query = this.searchParams.toString();
          return query ? '?' + query : '';
        },
        set: function(value) { this.searchParams = new URLSearchParams(value); }
      });
      Object.defineProperty(URL.prototype, 'href', {
        get: function() { return this.protocol + '//' + this.host + this.pathname + this.search + this.hash; }
      });
      URL.prototype.toString = function() { return this.href; };
      URL.prototype.toJSON = function() { return this.href; };
      globalThis.URL = URL;

      function Headers(init) {
        this._map = {};
        if (!init) return;
        if (typeof init.forEach === 'function') {
          init.forEach(function(value, key) { this.append(key, value); }, this);
        } else if (Array.isArray(init)) {
          for (var i = 0; i < init.length; i++) this.append(init[i][0], init[i][1]);
        } else {
          for (var key in init) this.append(key, init[key]);
        }
      }
      Headers.prototype.append = function(key, value) {
        key = String(key).toLowerCase();
        var existing = this._map[key];
        this._map[key] = existing ? existing + ', ' + String(value) : String(value);
      };
      Headers.prototype.set = function(key, value) {
        this._map[String(key).toLowerCase()] = String(value);
      };
      Headers.prototype.get = function(key) {
        var value = this._map[String(key).toLowerCase()];
        return value === undefined ? null : value;
      };
      Headers.prototype.has = function(key) {
        return Object.prototype.hasOwnProperty.call(this._map, String(key).toLowerCase());
      };
      Headers.prototype.forEach = function(cb, thisArg) {
        for (var key in this._map) cb.call(thisArg, this._map[key], key, this);
      };
      Headers.prototype.entries = function() {
        var out = [];
        for (var key in this._map) out.push([key, this._map[key]]);
        return out;
      };
      Headers.prototype.keys = function() {
        var out = [];
        for (var key in this._map) out.push(key);
        return out;
      };
      Headers.prototype.values = function() {
        var out = [];
        for (var key in this._map) out.push(this._map[key]);
        return out;
      };
      Headers.prototype[Symbol.iterator] = function() { return this.entries()[Symbol.iterator](); };
      globalThis.Headers = Headers;

      function FormData() { this._pairs = []; }
      FormData.prototype.append = function(key, value) { this._pairs.push([String(key), value]); };
      globalThis.FormData = FormData;

      function AbortSignal() {
        this.aborted = false;
        this.reason = undefined;
        this._listeners = [];
      }
      AbortSignal.prototype.addEventListener = function(type, fn) {
        if (type === 'abort') this._listeners.push(fn);
      };
      AbortSignal.prototype.removeEventListener = function(type, fn) {
        if (type !== 'abort') return;
        this._listeners = this._listeners.filter(function(listener) { return listener !== fn; });
      };
      function AbortController() { this.signal = new AbortSignal(); }
      AbortController.prototype.abort = function(reason) {
        if (this.signal.aborted) return;
        this.signal.aborted = true;
        this.signal.reason = reason || new Error('Aborted');
        var listeners = this.signal._listeners.slice();
        for (var i = 0; i < listeners.length; i++) listeners[i]();
      };
      globalThis.AbortSignal = AbortSignal;
      globalThis.AbortController = AbortController;

      function Response(body, init) {
        init = init || {};
        this._body = body == null ? '' : String(body);
        this.status = init.status || 200;
        this.statusText = init.statusText || '';
        this.ok = this.status >= 200 && this.status < 300;
        this.headers = new Headers(init.headers);
      }
      Response.prototype.text = function() { return Promise.resolve(this._body); };
      Response.prototype.json = function() { return Promise.resolve(JSON.parse(this._body || 'null')); };
      Response.prototype.clone = function() { return new Response(this._body, this); };
      globalThis.Response = Response;

      globalThis.fetch = function(input, init) {
        init = init || {};
        var url;
        if (typeof input === 'string') url = input;
        else if (input && typeof input.href === 'string') url = input.href;
        else if (input && input.url) url = String(input.url);
        else url = String(input);
        var method = (init.method || (input && input.method) || 'GET').toUpperCase();
        var headers = new Headers(init.headers || (input && input.headers));
        var body = init.body != null ? String(init.body) : (input && input.body != null ? String(input.body) : null);
        var signal = init.signal || (input && input.signal) || null;
        if (signal && signal.aborted) {
          return Promise.reject(new Error('The operation was aborted.'));
        }
        return new Promise(function(resolve, reject) {
          var settled = false;
          function fail(message) {
            if (settled) return;
            settled = true;
            reject(new Error(message));
          }
          function ok(payload) {
            if (settled) return;
            settled = true;
            resolve(new Response(payload.body, payload));
          }
          var id = __clerkNativeFetch(JSON.stringify({
            url: url,
            method: method,
            headers: headersToObject(headers),
            body: body
          }), function(err, result) {
            if (err) fail(String(err));
            else ok(typeof result === 'string' ? JSON.parse(result) : result);
          });
          if (signal) {
            signal.addEventListener('abort', function() {
              __clerkNativeAbortFetch(id);
              fail('The operation was aborted.');
            });
          }
        });
      };

      globalThis.atob = function(value) { return __clerkNativeAtob(String(value)); };
      globalThis.btoa = function(value) { return __clerkNativeBtoa(String(value)); };
      globalThis.setTimeout = function(fn, delay) { return __clerkNativeSetTimeout(fn, Number(delay) || 0); };
      globalThis.clearTimeout = function(id) { __clerkNativeClearTimeout(id); };
      globalThis.crypto = {
        getRandomValues: function(arr) {
          var bytes = __clerkNativeRandom(arr.length);
          for (var i = 0; i < arr.length; i++) arr[i] = bytes[i];
          return arr;
        }
      };
      globalThis.__clerkNativeGetToken = function() {
        return new Promise(function(resolve, reject) {
          __clerkNativeGetTokenImpl(function(err, token) {
            if (err) reject(new Error(String(err)));
            else resolve(token || '');
          });
        });
      };
      globalThis.__clerkNativeSaveToken = function(token) {
        return new Promise(function(resolve, reject) {
          __clerkNativeSaveTokenImpl(String(token), function(err) {
            if (err) reject(new Error(String(err)));
            else resolve();
          });
        });
      };
    })();
    """
}

private struct InFlightFetch {
  let callID: UInt64?
  let task: URLSessionDataTask
  let callback: JSValue
}
#endif
