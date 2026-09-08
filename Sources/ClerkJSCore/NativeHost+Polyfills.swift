#if !os(watchOS)
extension NativeHost {
  static let polyfillSource = """
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
      URLSearchParams.prototype.getAll = function(key) {
        key = String(key);
        return this._pairs.filter(function(pair) { return pair[0] === key; }).map(function(pair) { return pair[1]; });
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
        this.username = parsed.username;
        this.password = parsed.password;
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
          this._pathname = !value || value.charAt(0) === '/' ? value : '/' + value;
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
        get: function() {
          var credentials = this.username || this.password ? this.username + (this.password ? ':' + this.password : '') + '@' : '';
          return this.protocol + '//' + credentials + this.host + this.pathname + this.search + this.hash;
        }
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

      function Blob(parts, options) {
        this.type = options && options.type || '';
        this._binary = (parts || []).map(function(part) {
          if (part instanceof Blob) return part._binary;
          if (part instanceof ArrayBuffer) part = new Uint8Array(part);
          if (ArrayBuffer.isView(part)) {
            var bytes = new Uint8Array(part.buffer, part.byteOffset, part.byteLength);
            var result = '';
            for (var i = 0; i < bytes.length; i++) result += String.fromCharCode(bytes[i]);
            return result;
          }
          return unescape(encodeURIComponent(String(part)));
        }).join('');
        this.size = this._binary.length;
      }
      globalThis.Blob = Blob;
      function FormData() { this._pairs = []; }
      FormData.prototype.append = function(key, value, filename) { this._pairs.push([String(key), value, filename]); };
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
        var rawBody = init.body != null ? init.body : (input && input.body != null ? input.body : null);
        var body = rawBody == null ? null : String(rawBody);
        var bodyBase64 = null;
        if (rawBody instanceof FormData) {
          var boundary = '----clerk-' + Array.from(crypto.getRandomValues(new Uint8Array(16)), function(b) { return b.toString(16).padStart(2, '0'); }).join('');
          var multipart = '';
          rawBody._pairs.forEach(function(pair) {
            var name = pair[0].replace(/["\\r\\n]/g, '_');
            var value = pair[1];
            multipart += '--' + boundary + '\\r\\nContent-Disposition: form-data; name="' + name + '"';
            if (value instanceof Blob) {
              var filename = String(pair[2] || 'blob').replace(/["\\r\\n]/g, '_');
              multipart += '; filename="' + filename + '"\\r\\nContent-Type: ' + (value.type || 'application/octet-stream');
            }
            multipart += '\\r\\n\\r\\n' + (value instanceof Blob ? value._binary : unescape(encodeURIComponent(String(value)))) + '\\r\\n';
          });
          multipart += '--' + boundary + '--\\r\\n';
          headers.set('content-type', 'multipart/form-data; boundary=' + boundary);
          bodyBase64 = btoa(multipart);
          body = null;
        } else if (rawBody instanceof Blob) {
          bodyBase64 = btoa(rawBody._binary);
          body = null;
          if (!headers.has('content-type') && rawBody.type) headers.set('content-type', rawBody.type);
        }
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
            body: body,
            bodyBase64: bodyBase64
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
        subtle: {
          digest: function(algorithm, data) {
            var name = typeof algorithm === 'string' ? algorithm : algorithm && algorithm.name;
            if (String(name).toUpperCase() !== 'SHA-256') return Promise.reject(new Error('Unsupported digest algorithm'));
            var bytes = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
            return Promise.resolve(new Uint8Array(__clerkNativeSHA256(Array.from(bytes))).buffer);
          }
        },
        getRandomValues: function(arr) {
          var bytes = __clerkNativeRandom(arr.length);
          for (var i = 0; i < arr.length; i++) arr[i] = bytes[i];
          return arr;
        }
      };
      globalThis.__clerkNativeCommitState = function(state) {
        return new Promise(function(resolve, reject) {
          __clerkNativeCommitStateImpl(state, function(error) {
            if (error) reject(new Error(String(error)));
            else resolve();
          });
        });
      };
      globalThis.__clerkNativeStorage = function(request) {
        return new Promise(function(resolve, reject) {
          __clerkNativeStorageImpl(request, function(error, json) {
            if (error) { reject(new Error(error)); return; }
            try { resolve(JSON.parse(json)); } catch (error) { reject(error); }
          });
        });
      };
      globalThis.__clerkNativeBiometricCredential = function(request) {
        return new Promise(function(resolve, reject) {
          __clerkNativeBiometricCredentialImpl(request, function(failure, json) {
            if (failure) {
              var details = JSON.parse(failure);
              var error = new Error(details.message);
              error.code = details.code;
              error.nativeError = details.nativeError;
              reject(error);
              return;
            }
            try { resolve(JSON.parse(json)); } catch (error) { reject(error); }
          });
        });
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
      globalThis.__clerkNativeGetCachedResources = function() {
        return new Promise(function(resolve, reject) {
          __clerkNativeGetCachedResourcesImpl(function(err, json) {
            if (err) reject(new Error(String(err)));
            else resolve(json ? JSON.parse(json) : { client: null, environment: null });
          });
        });
      };
      globalThis.__clerkNativeSaveCachedResources = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativeSaveCachedResourcesImpl(String(payload), function(err) {
            if (err) reject(new Error(String(err)));
            else resolve();
          });
        });
      };
      function clerkNativePasskeyReject(err, fallbackCode, reject) {
        var parsed = err;
        if (typeof err === 'string') {
          try { parsed = JSON.parse(err); } catch (e) { parsed = { message: String(err) }; }
        }
        var error = new Error((parsed && parsed.message) ? String(parsed.message) : String(err));
        error.name = 'ClerkWebAuthnError';
        error.code = (parsed && parsed.code) ? String(parsed.code) : fallbackCode;
        reject(error);
      }
      globalThis.__clerkNativeCreatePublicCredentials = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativeCreatePublicCredentialsImpl(String(payload), function(err, json) {
            if (err) clerkNativePasskeyReject(err, 'passkey_registration_failed', reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      globalThis.__clerkNativeGetPublicCredentials = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativeGetPublicCredentialsImpl(String(payload), function(err, json) {
            if (err) clerkNativePasskeyReject(err, 'passkey_retrieval_failed', reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      function clerkNativeOAuthReject(err, reject) {
        var parsed = err;
        if (typeof err === 'string') {
          try { parsed = JSON.parse(err); } catch (e) { parsed = { message: String(err) }; }
        }
        var error = new Error((parsed && parsed.message) ? String(parsed.message) : String(err));
        error.name = 'ClerkOAuthError';
        error.code = (parsed && parsed.code) ? String(parsed.code) : 'oauth_session_failed';
        reject(error);
      }
      globalThis.__clerkNativeOAuthOpen = function(href, options) {
        return new Promise(function(resolve, reject) {
          __clerkNativeOAuthOpenImpl(String(href), !!(options && options.prefersEphemeralSession), function(err, callbackUrl) {
            if (err) clerkNativeOAuthReject(err, reject);
            else resolve(String(callbackUrl));
          });
        });
      };
      function clerkNativeAppleReject(err, reject) {
        var parsed = err;
        if (typeof err === 'string') {
          try { parsed = JSON.parse(err); } catch (e) { parsed = { message: String(err) }; }
        }
        var error = new Error((parsed && parsed.message) ? String(parsed.message) : String(err));
        error.name = 'ClerkAppleError';
        error.code = (parsed && parsed.code) ? String(parsed.code) : 'apple_failed';
        reject(error);
      }
      globalThis.__clerkNativeAppleSignIn = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativeAppleSignInImpl(String(payload || '{}'), function(err, json) {
            if (err) clerkNativeAppleReject(err, reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      function clerkNativeBiometricReject(err, reject) {
        var parsed = err;
        if (typeof err === 'string') {
          try { parsed = JSON.parse(err); } catch (e) { parsed = { message: String(err) }; }
        }
        var error = new Error((parsed && parsed.message) ? String(parsed.message) : String(err));
        error.name = 'ClerkBiometricError';
        error.code = (parsed && parsed.code) ? String(parsed.code) : 'biometric_authentication_failed';
        reject(error);
      }
      globalThis.__clerkNativeBiometricPresence = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativeBiometricPresenceImpl(String(payload || '{}'), function(err, json) {
            if (err) clerkNativeBiometricReject(err, reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      globalThis.__clerkNativePromptBiometrics = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativePromptBiometricsImpl(String(payload || '{}'), function(err, json) {
            if (err) clerkNativeBiometricReject(err, reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      function clerkNativeAppAttestReject(err, reject) {
        var parsed = err;
        if (typeof err === 'string') {
          try { parsed = JSON.parse(err); } catch (e) { parsed = { message: String(err) }; }
        }
        var error = new Error((parsed && parsed.message) ? String(parsed.message) : String(err));
        error.name = 'ClerkAppAttestError';
        error.code = (parsed && parsed.code) ? String(parsed.code) : 'device_attest_failed';
        reject(error);
      }
      globalThis.__clerkNativePrepareDeviceAttestation = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativePrepareDeviceAttestationImpl(String(payload || '{}'), function(err, json) {
            if (err) clerkNativeAppAttestReject(err, reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
      globalThis.__clerkNativePrepareDeviceAssertion = function(payload) {
        return new Promise(function(resolve, reject) {
          __clerkNativePrepareDeviceAssertionImpl(String(payload || '{}'), function(err, json) {
            if (err) clerkNativeAppAttestReject(err, reject);
            else resolve(typeof json === 'string' ? JSON.parse(json) : json);
          });
        });
      };
    })();
    """
}
#endif
