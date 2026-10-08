/// Stub implementation for non-web environments.
class BachsBridge {
  static Future<bool> openOverlayCheckout(String checkoutUrl) async {
    return false;
  }
}
