import 'package:url_launcher/url_launcher.dart';

/// Where G VPN's legal pages and source live. The admin panel's Legal page
/// publishes the two documents to these addresses.
abstract final class Legal {
  static final privacy = Uri.parse('https://cdn.mindberzerk.com/site/legal/g-vpn/privacy.html');
  static final terms = Uri.parse('https://cdn.mindberzerk.com/site/legal/g-vpn/terms.html');

  /// Google Play's own page for managing and cancelling subscriptions.
  static final subscriptions = Uri.parse('https://play.google.com/store/account/subscriptions?package=com.mindberzerk.gvpn');

  /// Opens in an in-app browser tab, so the user returns with one Back.
  static Future<void> open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
