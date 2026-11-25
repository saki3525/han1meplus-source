import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/site_url.dart';
import '../../data/remote/han1me_api.dart';
import '../../data/remote/webview_environment.dart';
import '../settings/settings_controller.dart';

class AccountWebPage extends ConsumerWidget {
  const AccountWebPage({super.key, required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(settingsProvider).valueOrNull?.resolvedBaseUrl ?? 'https://hanime1.me';
    final environment = ref.watch(webViewEnvironmentProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: environment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _webView(null, baseUrl),
        data: (environment) => _webView(environment, baseUrl),
      ),
    );
  }

  Widget _webView(WebViewEnvironment? environment, String baseUrl) => InAppWebView(
        webViewEnvironment: environment,
        initialUrlRequest: URLRequest(url: WebUri(siteEndpointUrl(baseUrl, path))),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          userAgent: Han1meApi.userAgent,
        ),
      );
}
