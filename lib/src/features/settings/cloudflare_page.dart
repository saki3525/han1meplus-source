import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

import '../../core/network/cloudflare_verification.dart';
import '../../data/remote/webview_cookie_bridge.dart';
import '../../data/remote/webview_environment.dart';
import '../account/account_controller.dart';
import 'settings_controller.dart';

class CloudflarePage extends ConsumerStatefulWidget {
  const CloudflarePage({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<CloudflarePage> createState() => _CloudflarePageState();
}

class _CloudflarePageState extends ConsumerState<CloudflarePage> {
  static const _pollInterval = Duration(milliseconds: 600);
  static const _challengeProbe = r"""
(function () {
  try {
    var title = (document.title || '').toLowerCase();
    var body = document.body;
    var text = (body && body.innerText ? body.innerText : '').toLowerCase();
    var marker = document.querySelector('#challenge-form, #challenge-running, #cf-challenge-running, .cf-browser-verification, [id*="cf-chl"], [class*="cf-chl"], script[src*="challenges.cloudflare.com"]');
    return marker !== null ||
      title.indexOf('just a moment') !== -1 ||
      title.indexOf('attention required') !== -1 ||
      text.indexOf('verifying you are human') !== -1 ||
      text.indexOf('checking your browser') !== -1;
  } catch (error) {
    return true;
  }
})()
""";

  InAppWebViewController? _controller;
  Timer? _timer;
  var _saving = false;
  var _completed = false;
  var _checking = false;
  var _reloadToken = 0;
  var _earliestCompletion = DateTime.fromMillisecondsSinceEpoch(0);

  String get _fallbackUrl => widget.initialUrl ?? ref.read(settingsProvider).valueOrNull?.resolvedBaseUrl ?? 'https://hanime1.me';

  Future<String> _readCookies(String url) async {
    final origin = CloudflareVerification.origin(url);
    if (origin.isEmpty) return '';
    return WebViewCookieBridge.read([origin]);
  }

  Future<String> _currentUrl() async => (await _controller?.getUrl())?.toString() ?? '';

  Future<bool> _challengeVisible() async {
    final controller = _controller;
    if (controller == null) return true;
    try {
      final result = await controller.evaluateJavascript(source: _challengeProbe);
      return result == true || result == 'true';
    } catch (_) {
      return true;
    }
  }

  Future<void> _check() async {
    if (!mounted || _saving || _completed || _checking) return;
    final controller = _controller;
    if (controller == null) return;
    _checking = true;
    try {
      final current = await _currentUrl();
      if (current.isEmpty || !CloudflareVerification.isSiteHost(CloudflareVerification.host(current))) return;
      if (DateTime.now().isBefore(_earliestCompletion)) return;
      if (await _challengeVisible()) return;
      final cookies = await _readCookies(current);
      if (CloudflareVerification.clearance(cookies) == null) return;
      await _complete(cookies, current);
    } finally {
      _checking = false;
    }
  }

  Future<void> _complete(String cookies, String url) async {
    if (!mounted || cookies.isEmpty || _saving || _completed) return;
    _saving = true;
    try {
      await ref.read(accountProvider.notifier).saveCloudflareCookie(cookies, url: url);
      await WebViewCookieBridge.syncToWebView(cookies, url);
      if (!mounted) return;
      _completed = true;
      _timer?.cancel();
      Navigator.pop(context, true);
    } catch (_) {
    } finally {
      _saving = false;
    }
  }

  Future<void> _finishManually() async {
    if (!mounted || _saving || _completed) return;
    final current = await _currentUrl();
    final url = CloudflareVerification.isSiteHost(CloudflareVerification.host(current)) ? current : _fallbackUrl;
    final cookies = await _readCookies(url);
    if (cookies.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.cloudflareVerificationIncomplete)));
      return;
    }
    await _complete(cookies, url);
  }

  void _startPolling() {
    if (_timer != null) return;
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_check()));
  }

  void _retry() {
    _timer?.cancel();
    _timer = null;
    _completed = false;
    setState(() => _reloadToken++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(settingsProvider).valueOrNull?.resolvedBaseUrl ?? 'https://hanime1.me';
    final initialUrl = widget.initialUrl ?? baseUrl;
    final environment = ref.watch(webViewEnvironmentProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cloudflareVerification),
        actions: [
          IconButton(
            tooltip: l10n.retry,
            onPressed: _completed ? null : _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: environment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(context, initialUrl, null, l10n),
        data: (environment) => _buildContent(context, initialUrl, environment, l10n),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String initialUrl, WebViewEnvironment? environment, AppLocalizations l10n) {
    return Stack(
      children: [
        InAppWebView(
          key: ValueKey(_reloadToken),
          webViewEnvironment: environment,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            thirdPartyCookiesEnabled: true,
            cacheEnabled: true,
          ),
          onWebViewCreated: (controller) async {
            _controller = controller;
            _startPolling();
            await controller.loadUrl(urlRequest: URLRequest(url: WebUri(initialUrl)));
          },
          onLoadStop: (controller, url) {
            final current = url?.toString();
            if (current == null || current.isEmpty) return;
            _earliestCompletion = DateTime.now().add(const Duration(milliseconds: 1200));
            unawaited(_check());
          },
          onReceivedHttpError: (controller, request, response) {
            if (request.isForMainFrame != true) return;
            final current = request.url.toString();
            if (current.isEmpty) return;
            unawaited(_check());
          },
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.cloudflareVerificationDescription, style: Theme.of(context).textTheme.bodySmall)),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _completed || _saving ? null : () => unawaited(_finishManually()),
                    child: Text(l10n.finishedVerification),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
