import 'dart:js_interop';

@JS('openBachsCheckout')
external void _openBachsCheckout(JSString url);

/// Web implementation using Bachs.js injected in index.html
class BachsBridge {
  static Future<bool> openOverlayCheckout(String checkoutUrl) async {
    try {
      _openBachsCheckout(checkoutUrl.toJS);
      return true;
    } catch (_) {
      return false;
    }
  }
}
