import Foundation
import WebKit
import SwiftUI

final class ProbeWebController: NSObject, ObservableObject, WKNavigationDelegate {
    static let startURL = "https://skyriver.top/index/index"

    let webView: WKWebView

    @Published var canGoBack = false
    @Published var pageTitle = "天河"
    @Published var currentURL = ""
    @Published var progress: Double = 0
    @Published var isReachable = true

    private let store: CaptureStore
    private var timer: Timer?
    private var progressObserver: NSKeyValueObservation?

    init(store: CaptureStore) {
        self.store = store

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(source: ProbeWebController.probeScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        // 用桌面 UA 打开，直接拿到「电脑版」的完整功能
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progress = webView.estimatedProgress
            }
        }

        load()
    }

    deinit {
        timer?.invalidate()
        progressObserver?.invalidate()
    }

    func load() {
        guard let url = URL(string: ProbeWebController.startURL) else { return }
        webView.load(URLRequest(url: url))
    }

    func reload() {
        webView.reload()
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func startPolling() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.drain()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func drain() {
        let js = "(function(){var l=window.__srLog||[];window.__srLog=[];return JSON.stringify(l);})()"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let array = object as? [[String: Any]] else { return }
            DispatchQueue.main.async {
                self.store.ingest(array)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isReachable = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canGoBack = webView.canGoBack
        pageTitle = webView.title ?? "天河"
        currentURL = webView.url?.absoluteString ?? ""
        isReachable = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        canGoBack = webView.canGoBack
        isReachable = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isReachable = false
    }
}

// MARK: - 注入脚本

extension ProbeWebController {
    /// 在页面里挂钩 fetch / XHR / 表单提交，把每个请求的地址、参数、响应头收集到 window.__srLog。
    static let probeScript = #"""
    (function () {
      if (window.__srHooked) { return; }
      window.__srHooked = true;
      window.__srLog = [];

      function push(item) {
        try {
          window.__srLog.push(item);
          if (window.__srLog.length > 400) { window.__srLog.shift(); }
        } catch (e) {}
      }

      function brief(text, limit) {
        if (!text) { return ""; }
        var s = String(text);
        return s.length > limit ? s.slice(0, limit) : s;
      }

      var rawFetch = window.fetch;
      if (rawFetch) {
        window.fetch = function (input, init) {
          var url = (typeof input === 'string') ? input : (input && input.url) || '';
          var method = (init && init.method) || (input && input.method) || 'GET';
          var body = (init && init.body) || '';
          return rawFetch.apply(this, arguments).then(function (response) {
            try {
              var clone = response.clone();
              clone.text().then(function (text) {
                push({ url: url, method: method.toUpperCase(), body: String(body),
                       status: response.status, resp: brief(text, 4000) });
              }).catch(function () {});
            } catch (e) {}
            return response;
          }).catch(function (error) {
            push({ url: url, method: method.toUpperCase(), body: String(body),
                   status: -1, resp: 'FETCH_ERROR ' + error });
            throw error;
          });
        };
      }

      var rawOpen = XMLHttpRequest.prototype.open;
      var rawSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function (method, url) {
        this.__srMeta = { method: method, url: url };
        return rawOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function (payload) {
        var xhr = this;
        xhr.addEventListener('load', function () {
          var meta = xhr.__srMeta || {};
          push({ url: String(meta.url || ''),
                 method: String(meta.method || 'GET').toUpperCase(),
                 body: payload ? String(payload) : '',
                 status: xhr.status,
                 resp: brief(xhr.responseText, 4000) });
        });
        return rawSend.apply(this, arguments);
      };

      document.addEventListener('submit', function (event) {
        var form = event.target;
        if (!form) { return; }
        var parts = [];
        try {
          new FormData(form).forEach(function (value, key) {
            parts.push(key + '=' + value);
          });
        } catch (e) {}
        push({ url: form.action || location.href,
               method: String(form.method || 'POST').toUpperCase(),
               body: parts.join('&'),
               status: -2,
               resp: 'FORM_SUBMIT' });
      }, true);

      var seen = {};
      setInterval(function () {
        try {
          var entries = performance.getEntriesByType('resource') || [];
          for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (entry.initiatorType !== 'xmlhttprequest' && entry.initiatorType !== 'fetch') { continue; }
            if (seen[entry.name]) { continue; }
            seen[entry.name] = true;
            push({ url: entry.name, method: 'GET', body: '', status: -3, resp: 'TIMING_ONLY' });
          }
        } catch (e) {}
      }, 3000);
    })();
    """#
}
