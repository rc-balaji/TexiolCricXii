import 'package:cricxii_ground_ar/cricxii_ground_ar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/ground_layout.dart';

enum GroundArSupport { supported, installRequired, unsupported, checking }

abstract class GroundArGateway {
  Future<GroundArSupport> availability();
  Future<GroundLayout?> open(GroundLayout layout);
}

class NativeGroundArGateway implements GroundArGateway {
  const NativeGroundArGateway();

  @override
  Future<GroundArSupport> availability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return GroundArSupport.unsupported;
    }
    try {
      return switch (await GroundArBridge.availability()) {
        'supported' => GroundArSupport.supported,
        'installRequired' => GroundArSupport.installRequired,
        'unsupported' => GroundArSupport.unsupported,
        _ => GroundArSupport.checking,
      };
    } on MissingPluginException {
      return GroundArSupport.unsupported;
    }
  }

  @override
  Future<GroundLayout?> open(GroundLayout layout) async {
    final result = await GroundArBridge.openGround(layout.toJson());
    return result == null ? null : GroundLayout.fromJson(result);
  }
}
