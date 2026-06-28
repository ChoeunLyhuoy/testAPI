// lib/utils/image_helper.dart
//
// FIX: this used to have its own copy of the localhost->real-server
// rewrite logic, hardcoded to `serverHost = '192.168.0.110'` — which is
// actually the API host, not the image host. ApiService (the other place
// that resolves image URLs, via `ApiService.imageUrl()`) points images at
// a *different* host (`10.250.0.76`). Depending on which helper a given
// screen happened to call, the same image URL could resolve to two
// different servers — and the wrong one (the API host doesn't serve
// /server/image/... paths) would just fail to load.
//
// Now there is exactly one place that knows the image host:
// ApiService.imageUrl(). ImageHelper just forwards to it, so every screen
// resolves images the same way and a future host change only has to be
// made in one place.

import '../services/api_service.dart';

class ImageHelper {
  ImageHelper._();

  static String resolve(String? raw) => ApiService.imageUrl(raw);

  static bool isValid(String? raw) => resolve(raw).isNotEmpty;
}
