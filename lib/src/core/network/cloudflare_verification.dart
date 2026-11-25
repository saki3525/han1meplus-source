import '../site_hosts.dart';

class CloudflareVerification {
  CloudflareVerification._();

  static String origin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    return '${uri.scheme}://${uri.authority}/';
  }

  static String? clearance(String cookies) {
    for (final part in cookies.split(';')) {
      final value = part.trim();
      if (value.toLowerCase().startsWith('cf_clearance=')) return value;
    }
    return null;
  }

  static bool isSiteHost(String host) {
    final value = host.toLowerCase();
    return hanimeSiteHosts.contains(value) || hanimeSiteHosts.any((domain) => value.endsWith('.$domain'));
  }

  static String host(String url) => Uri.tryParse(url)?.host ?? '';

  static String normalizedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final normalizedHost = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    if (!hanimeSiteHosts.contains(normalizedHost)) return url;
    return uri.replace(host: normalizedHost).toString();
  }
}
