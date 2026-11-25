import '../../core/desktop_platform.dart';
import '../../core/settings.dart';
import '../local/json_store.dart';
import 'han1me_http_client.dart';
import 'webview_cookie_bridge.dart';

Future<void> bootstrapDesktopNetwork([AppSettings? settings]) async {
  if (!isDesktopHttpPlatform) return;
  final resolved = settings ?? await SettingsStore(JsonStore()).load();
  await _importWebViewCookies(resolved);
  await Han1meHttpClient().setNetworkSettings(
    useBuiltInHosts: resolved.useBuiltInHosts,
    useDoh: resolved.useDoh,
    dohPreset: resolved.dohPreset,
    dohCustomUrl: resolved.dohCustomUrl,
    dohBootstrapIps: resolved.dohBootstrapIps,
    dohTimeoutSeconds: resolved.dohTimeoutSeconds,
    mediaCdnRegion: resolved.mediaCdnRegion,
    mediaCdnCustomIp: resolved.mediaCdnCustomIp,
  );
}

Future<void> _importWebViewCookies(AppSettings settings) async {
  final urls = <String>{settings.resolvedBaseUrl, ...WebViewCookieBridge.urls};
  final client = Han1meHttpClient();
  for (final url in urls) {
    final cookies = await WebViewCookieBridge.read([url]);
    if (cookies.isEmpty) continue;
    await client.saveCookies(cookies, url: url, broadcast: false);
  }
}
