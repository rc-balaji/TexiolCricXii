import 'dart:math' as math;

/// Metric geometry. Imperial law dimensions are converted without display rounding.
class GroundLayout {
  const GroundLayout({
    this.lengthMetres = standardLength,
    this.runUpMetres = 0,
    this.wideOffsetMetres = .9,
    this.showCreases = true,
    this.showStumps = true,
    this.wideGuides = false,
  });

  static const standardLength = 22 * .9144;
  static const minLength = 4.0;
  static const maxLength = 40.0;
  static const pitchWidth = 10 * .3048;
  static const poppingOffset = 4 * .3048;
  static const returnOffset = 52 * .0254;
  static const bowlingWidth = 104 * .0254;
  static const poppingWidth = 12 * .3048;
  static const returnLength = 8 * .3048;
  static const stumpHeight = 28 * .0254;
  static const wicketWidth = 9 * .0254;

  final double lengthMetres;
  final double runUpMetres;
  final double wideOffsetMetres;
  final bool showCreases;
  final bool showStumps;
  final bool wideGuides;

  bool get isStandard => (lengthMetres - standardLength).abs() < .0001;
  double get lengthYards => lengthMetres / .9144;

  GroundLayout copyWith({
    double? lengthMetres,
    double? runUpMetres,
    double? wideOffsetMetres,
    bool? showCreases,
    bool? showStumps,
    bool? wideGuides,
  }) {
    final length = lengthMetres ?? this.lengthMetres;
    final runUp = runUpMetres ?? this.runUpMetres;
    final wide = wideOffsetMetres ?? this.wideOffsetMetres;
    if (!length.isFinite || length < minLength || length > maxLength) {
      throw ArgumentError('Pitch length must be between 4 and 40 metres.');
    }
    if (!runUp.isFinite || runUp < 0 || runUp > 20) {
      throw ArgumentError('Run-up must be between 0 and 20 metres.');
    }
    if (!wide.isFinite || wide < .3 || wide > 1.3) {
      throw ArgumentError('Guide offset must be between 0.3 and 1.3 metres.');
    }
    return GroundLayout(
      lengthMetres: length,
      runUpMetres: runUp,
      wideOffsetMetres: wide,
      showCreases: showCreases ?? this.showCreases,
      showStumps: showStumps ?? this.showStumps,
      wideGuides: wideGuides ?? this.wideGuides,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'lengthMetres': lengthMetres,
    'runUpMetres': runUpMetres,
    'wideOffsetMetres': wideOffsetMetres,
    'showCreases': showCreases,
    'showStumps': showStumps,
    'wideGuides': wideGuides,
  };

  factory GroundLayout.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback, double min, double max) {
      final value = json[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.toDouble().clamp(min, max);
    }

    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return GroundLayout(
      lengthMetres: number(
        'lengthMetres',
        standardLength,
        minLength,
        maxLength,
      ),
      runUpMetres: number('runUpMetres', 0, 0, 20),
      wideOffsetMetres: number('wideOffsetMetres', .9, .3, 1.3),
      showCreases: flag('showCreases', true),
      showStumps: flag('showStumps', true),
      wideGuides: flag('wideGuides', false),
    );
  }

  /// End-local markings; positive y points into the pitch at either end.
  List<GroundLine> get endLines => [
    if (showCreases) ...[
      const GroundLine(-bowlingWidth / 2, 0, bowlingWidth / 2, 0),
      const GroundLine(
        -poppingWidth / 2,
        poppingOffset,
        poppingWidth / 2,
        poppingOffset,
      ),
      for (final sign in [-1, 1])
        GroundLine(
          sign * returnOffset,
          poppingOffset,
          sign * returnOffset,
          poppingOffset - returnLength,
        ),
    ],
    if (wideGuides)
      for (final sign in [-1, 1])
        GroundLine(
          sign * wideOffsetMetres,
          0,
          sign * wideOffsetMetres,
          poppingOffset,
          isGuide: true,
        ),
  ];
}

class GroundLine {
  const GroundLine(this.x1, this.y1, this.x2, this.y2, {this.isGuide = false});
  final double x1, y1, x2, y2;
  final bool isGuide;
}

/// A diagram placement, never a claim about a saved physical AR anchor.
class GroundSetup {
  const GroundSetup({
    this.layout = const GroundLayout(),
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.placed = true,
    this.locked = false,
    this.endsSwapped = false,
  });

  final GroundLayout layout;
  final double x, y, rotation;
  final bool placed, locked, endsSwapped;

  GroundSetup copyWith({
    GroundLayout? layout,
    double? x,
    double? y,
    double? rotation,
    bool? placed,
    bool? locked,
    bool? endsSwapped,
  }) => GroundSetup(
    layout: layout ?? this.layout,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation == null ? this.rotation : normalizeAngle(rotation),
    placed: placed ?? this.placed,
    locked: locked ?? this.locked,
    endsSwapped: endsSwapped ?? this.endsSwapped,
  );

  static double normalizeAngle(double value) {
    if (!value.isFinite) return 0;
    if (value >= -math.pi && value < math.pi) return value;
    return ((value + math.pi) % (2 * math.pi)) - math.pi;
  }

  Map<String, Object?> toJson() => {
    ...layout.toJson(),
    'x': x,
    'y': y,
    'rotation': rotation,
    'placed': placed,
    'locked': locked,
    'endsSwapped': endsSwapped,
  };

  factory GroundSetup.fromJson(Map<String, dynamic> json) {
    double finite(String key) {
      final value = json[key];
      return value is num && value.isFinite ? value.toDouble() : 0;
    }

    return GroundSetup(
      layout: GroundLayout.fromJson(json),
      x: finite('x').clamp(-50, 50),
      y: finite('y').clamp(-50, 50),
      rotation: normalizeAngle(finite('rotation')),
      placed: json['placed'] != false,
      locked: json['locked'] == true,
      endsSwapped: json['endsSwapped'] == true,
    );
  }
}
