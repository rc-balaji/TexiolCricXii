import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/ground_layout.dart';
import '../services/ground_setup_controller.dart';

class GroundPreview extends StatefulWidget {
  const GroundPreview({required this.controller, super.key});
  final GroundSetupController controller;

  @override
  State<GroundPreview> createState() => _GroundPreviewState();
}

class _GroundPreviewState extends State<GroundPreview> {
  double _zoom = 1;
  double _startZoom = 1;
  Offset _pan = Offset.zero;
  Offset _lastFocal = Offset.zero;
  bool _move = true;
  int? _viewResetRevision;

  @override
  void didUpdateWidget(covariant GroundPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _viewResetRevision = null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (_viewResetRevision != widget.controller.viewResetRevision) {
        _viewResetRevision = widget.controller.viewResetRevision;
        _zoom = 1;
        _startZoom = 1;
        _pan = Offset.zero;
      }
      final setup = widget.controller.value;
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 390,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final base = GroundPitchPainter.fitScale(size, setup);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Semantics(
                      label:
                          'Interactive top view. ${setup.layout.lengthYards.toStringAsFixed(1)} yard pitch. '
                          '${setup.locked ? 'Layout locked.' : 'Drag to move. Pinch to zoom.'} '
                          'This diagram does not measure the ground.',
                      child: GestureDetector(
                        key: const ValueKey('ground-preview'),
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (details) {
                          _startZoom = _zoom;
                          _lastFocal = details.localFocalPoint;
                          widget.controller.beginGesture();
                        },
                        onScaleUpdate: (details) {
                          final delta = details.localFocalPoint - _lastFocal;
                          _lastFocal = details.localFocalPoint;
                          if (details.pointerCount > 1) {
                            setState(
                              () =>
                                  _zoom = (_startZoom * details.scale).clamp(
                                    .6,
                                    4,
                                  ),
                            );
                          } else if (_move && !setup.locked && setup.placed) {
                            widget.controller.moveBy(
                              delta.dx / (base * _zoom),
                              delta.dy / (base * _zoom),
                            );
                          } else {
                            setState(() => _pan += delta);
                          }
                        },
                        onScaleEnd: (_) => widget.controller.endGesture(),
                        child: CustomPaint(
                          painter: GroundPitchPainter(
                            setup,
                            zoom: _zoom,
                            pan: _pan,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _Tag(
                      label: setup.locked ? 'LAYOUT LOCKED' : 'TOP VIEW',
                      icon:
                          setup.locked
                              ? Icons.lock_outline
                              : Icons.map_outlined,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Fit pitch in view',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xCC193D32),
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          () => setState(() {
                            _zoom = 1;
                            _pan = Offset(-setup.x * base, -setup.y * base);
                          }),
                      icon: const Icon(Icons.center_focus_strong, size: 20),
                    ),
                  ),
                  if (!setup.placed)
                    Center(
                      child: FilledButton.icon(
                        onPressed:
                            setup.locked
                                ? null
                                : () => widget.controller.change(
                                  setup.copyWith(placed: true, x: 0, y: 0),
                                ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Place pitch'),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!setup.locked)
                          Material(
                            color: const Color(0xDD163D30),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => _move = !_move),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _move
                                          ? Icons.open_with
                                          : Icons.pan_tool_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _move ? 'Move pitch' : 'Pan view',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const _Tag(
                          label: 'PINCH TO ZOOM',
                          icon: Icons.pinch_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xCF15382D),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFADF1CE), size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class GroundPitchPainter extends CustomPainter {
  GroundPitchPainter(this.setup, {this.zoom = 1, this.pan = Offset.zero});
  final GroundSetup setup;
  final double zoom;
  final Offset pan;

  static double fitScale(Size size, GroundSetup setup) {
    final length = setup.layout.lengthMetres + setup.layout.runUpMetres + 6;
    final c = math.cos(setup.rotation).abs();
    final s = math.sin(setup.rotation).abs();
    return math.max(.1, math.min(
      (size.width - 65) / (10 * c + length * s),
      (size.height - 104) / (length * c + 10 * s),
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF174A37), Color(0xFF08281F)],
        ).createShader(full),
    );
    final scale = fitScale(size, setup) * zoom;
    final grid =
        Paint()
          ..color = const Color(0x1378C59C)
          ..strokeWidth = .6;
    final gridSpacing = math.max(10.0, scale * 2);
    for (var x = pan.dx % gridSpacing; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = pan.dy % gridSpacing; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!setup.placed) return;
    final layout = setup.layout;
    canvas.save();
    final shift = layout.runUpMetres * scale / 2 * (setup.endsSwapped ? -1 : 1);
    canvas.translate(
      size.width / 2 + pan.dx - math.sin(setup.rotation) * shift,
      size.height / 2 + pan.dy + math.cos(setup.rotation) * shift,
    );
    canvas.scale(scale);
    canvas.translate(setup.x, setup.y);
    canvas.rotate(setup.rotation);
    final length = layout.lengthMetres;
    final half = length / 2;
    final pitch = Rect.fromLTWH(
      -GroundLayout.pitchWidth / 2,
      -half - .8,
      GroundLayout.pitchWidth,
      length + 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitch.inflate(.18), const Radius.circular(.15)),
      Paint()..color = const Color(0x27000000),
    );
    canvas.drawRect(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFAA9670), Color(0xFFC5B087), Color(0xFFAE9C76)],
        ).createShader(pitch),
    );
    final stripe = Paint()..color = const Color(0x0DFFFFFF);
    for (var i = -half; i < half; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(
          -GroundLayout.pitchWidth / 2,
          i,
          GroundLayout.pitchWidth,
          math.min(1, half - i),
        ),
        stripe,
      );
    }
    final centre =
        Paint()
          ..color = const Color(0xAFC5EDD8)
          ..strokeWidth = 1 / scale;
    for (double y = -half; y < half; y += .7) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + .32, half)), centre);
    }
    for (final far in [false, true]) {
      final endY = far ? -half : half;
      final direction = far ? 1 : -1;
      for (final line in layout.endLines) {
        canvas.drawLine(
          Offset(line.x1, endY + direction * line.y1),
          Offset(line.x2, endY + direction * line.y2),
          Paint()
            ..color =
                line.isGuide ? const Color(0xFFFFC669) : const Color(0xFFF9FFF9)
            ..strokeWidth = math.max(.045, 1.2 / scale),
        );
      }
      if (layout.showStumps) {
        final shadow = Paint()..color = const Color(0x99000000);
        final stumps =
            Paint()
              ..color = const Color(0xFFFFCB6B)
              ..strokeWidth = math.max(.035, 2.2 / scale)
              ..strokeCap = StrokeCap.round;
        for (final x in [-.095, 0.0, .095]) {
          canvas.drawCircle(Offset(x + .03, endY + .05), .045, shadow);
          canvas.drawLine(Offset(x, endY - .08), Offset(x, endY + .08), stumps);
        }
      }
      final bowling = far != setup.endsSwapped;
      _label(
        canvas,
        bowling ? 'BOWLING END' : 'BATTING END',
        Offset(0, endY + (far ? -.8 : 1)),
        scale,
        size: 9,
        color: const Color(0xFFD1ECDA),
      );
    }
    final dimX = 2.7;
    final dim =
        Paint()
          ..color = const Color(0xFF77BD98)
          ..strokeWidth = 1 / scale;
    canvas.drawLine(Offset(dimX, -half), Offset(dimX, half), dim);
    for (final y in [-half, half]) {
      canvas.drawLine(Offset(dimX - .18, y), Offset(dimX + .18, y), dim);
    }
    _label(
      canvas,
      '${layout.lengthYards.toStringAsFixed(layout.isStandard ? 0 : 1)} yd',
      Offset(dimX + .65, -.35),
      scale,
      color: Colors.white,
      size: 12,
    );
    _label(
      canvas,
      '${length.toStringAsFixed(2)} m',
      Offset(dimX + .65, .65),
      scale,
      size: 8,
    );
    if (layout.runUpMetres > 0) {
      final sign = setup.endsSwapped ? 1 : -1;
      final y = sign * (half + layout.runUpMetres);
      for (double d = 1.5; d < layout.runUpMetres; d += .8) {
        final p = sign * (half + d);
        canvas.drawLine(Offset(0, p), Offset(0, p + sign * .3), centre);
      }
      canvas.drawLine(
        Offset(-.5, y),
        Offset(.5, y),
        Paint()
          ..color = const Color(0xFFFFC669)
          ..strokeWidth = 2 / scale,
      );
      _label(
        canvas,
        '${layout.runUpMetres.toStringAsFixed(1)} m RUN-UP',
        Offset(0, y + sign * .7),
        scale,
        size: 8,
      );
    }
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double scale, {
    double size = 10,
    Color color = const Color(0xFFADE0C1),
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-setup.rotation);
    canvas.scale(1 / scale);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GroundPitchPainter oldDelegate) =>
      oldDelegate.setup != setup ||
      oldDelegate.zoom != zoom ||
      oldDelegate.pan != pan;
}
