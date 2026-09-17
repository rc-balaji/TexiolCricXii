import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The native view uses a fresh, local ARCore session on every launch.
/// Only layout preferences cross this bridge; world anchors never do.
abstract final class GroundArBridge {
  static const _channel = MethodChannel('com.texiol.crixx/ground_ar');

  /// supported, installRequired, unsupported, or checking.
  static Future<String> availability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'unsupported';
    }
    try {
      return await _channel.invokeMethod<String>('availability') ??
          'unsupported';
    } on MissingPluginException {
      return 'unsupported';
    }
  }

  static Future<Map<String, Object?>?> openGround(
    Map<String, Object?> layout,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'openGround',
      layout,
    );
    return result == null ? null : Map<String, Object?>.from(result);
  }
}
