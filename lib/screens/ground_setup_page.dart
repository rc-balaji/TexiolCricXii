import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/ground_layout.dart';
import '../services/ground_ar_service.dart';
import '../services/ground_setup_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ground_preview.dart';

class GroundSetupPage extends StatefulWidget {
  const GroundSetupPage({super.key, this.repository, this.arGateway});
  final GroundSetupRepository? repository;
  final GroundArGateway? arGateway;

  @override
  State<GroundSetupPage> createState() => _GroundSetupPageState();
}

class _GroundSetupPageState extends State<GroundSetupPage> {
  final _controller = GroundSetupController();
  final _previewKey = GlobalKey();
  late final GroundSetupRepository _repository;
  late final GroundArGateway _ar;
  GroundArSupport _support = GroundArSupport.checking;
  bool _loading = true;
  bool _opening = false;
  bool _saving = false;
  bool _checking = false;
  bool _saved = false;
  bool _sharing = false;
  String? _supportError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GroundSetupRepository();
    _ar = widget.arGateway ?? const NativeGroundArGateway();
    _controller.addListener(_changed);
    _load();
    _checkSupport();
  }

  void _changed() {
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _load() async {
    try {
      final setup = await _repository.load();
      if (!mounted) return;
      if (setup != null) _controller.restore(setup);
    } catch (_) {
      if (mounted)
        _message('Saved layout could not be loaded. You can create a new one.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkSupport() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _supportError = null;
    });
    try {
      var result = await _ar.availability();
      for (
        var attempt = 0;
        attempt < 3 && result == GroundArSupport.checking;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        result = await _ar.availability();
      }
      if (mounted) setState(() => _support = result);
    } catch (_) {
      if (mounted)
        setState(
          () => _supportError = 'Could not check AR support. Tap retry.',
        );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openAr() async {
    if (_opening || _loading) return;
    setState(() => _opening = true);
    try {
      final updated = await _ar.open(_controller.value.layout);
      if (!mounted) return;
      if (updated != null) {
        final locked = _controller.value.locked;
        _controller.setLocked(false);
        _controller.change(_controller.value.copyWith(layout: updated));
        _controller.setLocked(locked);
        await _save();
      }
    } on PlatformException catch (error) {
      if (mounted)
        _message(
          error.message ??
              'AR could not start. Your top-view layout is still available.',
        );
    } catch (_) {
      if (mounted)
        _message(
          'AR could not start. Please retry or use the top-view layout.',
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final snapshot = _controller.value;
    setState(() => _saving = true);
    try {
      await _repository.save(snapshot);
      if (mounted) {
        setState(() => _saved = identical(snapshot, _controller.value));
        _message('Layout saved on this phone. Scan again to place it in AR.');
      }
    } catch (_) {
      if (mounted) _message('Could not save the layout. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editLength() async {
    final field = TextEditingController(
      text: _controller.value.layout.lengthYards.toStringAsFixed(2),
    );
    String? error;
    final result = await showDialog<double>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Custom pitch length'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distance between the two bowling creases. Stumps and creases keep their standard sizes.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('custom-pitch-length'),
                        controller: field,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Length in yards',
                          helperText: '4.38–43.74 yd (4–40 m)',
                          errorText: error,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final yards = double.tryParse(field.text.trim());
                        final metres = yards == null ? null : yards * .9144;
                        if (metres == null ||
                            !metres.isFinite ||
                            metres < GroundLayout.minLength ||
                            metres > GroundLayout.maxLength) {
                          setDialogState(
                            () =>
                                error =
                                    'Enter a distance between 4 and 40 metres in yards.',
                          );
                          return;
                        }
                        Navigator.pop(context, metres);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
          ),
    );
    // The dialog route may still be animating out when its result resolves.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
    if (!mounted || result == null) return;
    _controller.change(
      _controller.value.copyWith(
        layout: _controller.value.layout.copyWith(lengthMetres: result),
      ),
    );
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset ground layout?'),
            content: const Text(
              'Return to a 22-yard pitch and default guides. You can undo this change.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep layout'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) _controller.reset();
  }

  Future<void> _help() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set up the pitch, step by step',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                const Text(
                  '1. Scan a clear patch of ground by moving the camera slowly.\n\n'
                  '2. Place the batting stumps, then choose the bowling direction.\n\n'
                  '3. Walk towards the preview at the other end. Scan that surface and confirm the bowling stumps.\n\n'
                  '4. Check both ends, adjust, then lock. Use the guides to place physical stumps and mark creases.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Measurement and tracking',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AR estimates position. Grass, glare and long walks can cause drift. Verify important distances with a tape. '
                  'Tracking quality is not a measurement-accuracy guarantee. Top view is a planning diagram and does not measure distance. '
                  'Saved setups keep dimensions; each new camera session needs a fresh scan.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Standard geometry: 22 yd pitch; 10 ft pitch width; popping crease 4 ft in front of the bowling crease; '
                  'return creases 4 ft 4 in either side of the centreline. Stumps: 28 in high, 9 in total wicket width. '
                  'Custom wide guides are practice markings, not an automatic wide/no-ball decision.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'AR uses Google Play Services for AR, provided by Google LLC and governed by the Google Privacy Policy.',
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      if (!await launchUrl(
                            Uri.parse('https://policies.google.com/privacy'),
                            mode: LaunchMode.externalApplication,
                          ) &&
                          mounted) {
                        _message(
                          'Google Privacy Policy: policies.google.com/privacy',
                        );
                      }
                    } catch (_) {
                      if (mounted)
                        _message(
                          'Google Privacy Policy: policies.google.com/privacy',
                        );
                    }
                  },
                  child: const Text('Google Privacy Policy'),
                ),
              ],
            ),
          ),
        ),
  );

  Future<void> _share() async {
    final layout = _controller.value.layout;
    await Clipboard.setData(
      ClipboardData(
        text:
            'CricXii ground setup\n'
            'Pitch: ${layout.lengthYards.toStringAsFixed(2)} yd / ${layout.lengthMetres.toStringAsFixed(3)} m\n'
            'Popping crease: 1.2192 m from bowling crease\nReturn creases: 1.3208 m either side of centre\n'
            '${layout.wideGuides ? 'Custom guide offset: ${layout.wideOffsetMetres.toStringAsFixed(2)} m\n' : ''}'
            '${layout.runUpMetres > 0 ? 'Run-up: ${layout.runUpMetres.toStringAsFixed(1)} m\n' : ''}'
            'AR placement is approximate; verify on the ground.',
      ),
    );
    if (mounted) _message('Ground dimensions copied.');
  }

  Future<void> _sharePicture() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    ui.Image? image;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _previewKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not capture the layout.');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/cricxii_ground_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'CricXii ground plan · ${_controller.value.layout.lengthYards.toStringAsFixed(2)} yd. '
            'Top-view diagram; verify physical distances on the ground.',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      if (mounted) _message('Could not share the image. You can still copy the dimensions.');
    } finally {
      image?.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = _controller.value;
    final layout = setup.layout;
    final canAr =
        _support == GroundArSupport.supported ||
        _support == GroundArSupport.installRequired;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ground',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _help,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ground setup help',
          ),
          IconButton(
            onPressed: _loading || _saving ? null : _save,
            icon: Icon(
              _saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
            ),
            tooltip: 'Save ground setup',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: AppColors.ink,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.view_in_ar_rounded,
                                    color: AppColors.green,
                                    size: 19,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(
                                    'CRICXII  /  GROUND AR',
                                    style: TextStyle(
                                      color: Color(0xFFA7DCC1),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                                  )),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Your ground.\nReady for cricket.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                  letterSpacing: -.7,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Place the stumps. Align the pitch.\nMark every crease with confidence.',
                                style: TextStyle(
                                  color: Color(0xFFB4C9BF),
                                  height: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                key: const ValueKey('open-ground-ar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: AppColors.ink,
                                ),
                                onPressed: canAr && !_opening ? _openAr : null,
                                icon:
                                    _opening
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.camera_alt_outlined),
                                label: Text(
                                  _opening
                                      ? 'Opening camera…'
                                      : _support ==
                                          GroundArSupport.installRequired
                                      ? 'Set up AR & open camera'
                                      : 'Open AR camera',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    canAr
                                        ? Icons.check_circle_outline
                                        : Icons.info_outline,
                                    size: 14,
                                    color: const Color(0xFFA7DCC1),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      _supportError ??
                                          switch (_support) {
                                            GroundArSupport.supported =>
                                              'AR supported · new ground scan each session',
                                            GroundArSupport.installRequired =>
                                              'Google Play Services for AR needs installation or update.',
                                            GroundArSupport.unsupported =>
                                              'AR unavailable on this device. Use the interactive layout below to plan and mark manually.',
                                            GroundArSupport.checking =>
                                              _checking
                                                  ? 'Checking this device for AR support…'
                                                  : 'AR support is not confirmed. Retry when connected.',
                                          },
                                      style: const TextStyle(
                                        color: Color(0xFFB4C9BF),
                                        fontSize: 11,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!canAr && !_checking)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.green,
                                  ),
                                  onPressed: _checkSupport,
                                  child: const Text('Retry AR check'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pitch layout',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${layout.lengthMetres.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                color: AppColors.greenDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'A movable plan. Use AR or a tape to mark it on the ground.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Standard · 22 yd'),
                              selected: layout.isStandard,
                              onSelected:
                                  setup.locked
                                      ? null
                                      : (_) => _controller.change(
                                        setup.copyWith(
                                          layout: layout.copyWith(
                                            lengthMetres:
                                                GroundLayout.standardLength,
                                          ),
                                        ),
                                      ),
                            ),
                            ChoiceChip(
                              key: const ValueKey('custom-length'),
                              label: Text(
                                layout.isStandard
                                    ? 'Custom length'
                                    : '${layout.lengthYards.toStringAsFixed(2)} yd · Edit',
                              ),
                              selected: !layout.isStandard,
                              onSelected:
                                  setup.locked ? null : (_) => _editLength(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(key: _previewKey, child: GroundPreview(controller: _controller)),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed:
                                  _controller.canUndo ? _controller.undo : null,
                              icon: const Icon(Icons.undo),
                              tooltip: 'Undo layout change',
                            ),
                            IconButton(
                              onPressed:
                                  _controller.canRedo ? _controller.redo : null,
                              icon: const Icon(Icons.redo),
                              tooltip: 'Redo layout change',
                            ),
                            IconButton(
                              onPressed:
                                  setup.locked
                                      ? null
                                      : () => _controller.change(
                                        setup.copyWith(
                                          rotation:
                                              setup.rotation - math.pi / 36,
                                        ),
                                      ),
                              icon: const Icon(Icons.rotate_left),
                              tooltip: 'Rotate left 5 degrees',
                            ),
                            IconButton(
                              onPressed:
                                  setup.locked
                                      ? null
                                      : () => _controller.change(
                                        setup.copyWith(
                                          rotation:
                                              setup.rotation + math.pi / 36,
                                        ),
                                      ),
                              icon: const Icon(Icons.rotate_right),
                              tooltip: 'Rotate right 5 degrees',
                            ),
                            IconButton(
                              onPressed:
                                  () => _controller.setLocked(!setup.locked),
                              icon: Icon(
                                setup.locked ? Icons.lock : Icons.lock_open,
                              ),
                              tooltip:
                                  setup.locked
                                      ? 'Unlock layout'
                                      : 'Lock layout',
                            ),
                            IconButton(
                              onPressed:
                                  setup.locked || !setup.placed
                                      ? null
                                      : () => _controller.change(
                                        setup.copyWith(placed: false),
                                      ),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove pitch placement',
                            ),
                          ],
                        ),
                        if (setup.locked)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Layout locked. Unlock to change dimensions or move the pitch.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Markings & run-up',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Stumps'),
                                  subtitle: const Text(
                                    'Standard size at both ends',
                                  ),
                                  value: layout.showStumps,
                                  onChanged:
                                      setup.locked
                                          ? null
                                          : (value) => _controller.change(
                                            setup.copyWith(
                                              layout: layout.copyWith(
                                                showStumps: value,
                                              ),
                                            ),
                                          ),
                                ),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Crease lines'),
                                  subtitle: const Text(
                                    'Bowling, popping and return creases',
                                  ),
                                  value: layout.showCreases,
                                  onChanged:
                                      setup.locked
                                          ? null
                                          : (value) => _controller.change(
                                            setup.copyWith(
                                              layout: layout.copyWith(
                                                showCreases: value,
                                              ),
                                            ),
                                          ),
                                ),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Custom wide guides'),
                                  subtitle: const Text(
                                    'Practice guides · no automatic wide decisions',
                                  ),
                                  value: layout.wideGuides,
                                  onChanged:
                                      setup.locked
                                          ? null
                                          : (value) => _controller.change(
                                            setup.copyWith(
                                              layout: layout.copyWith(
                                                wideGuides: value,
                                              ),
                                            ),
                                          ),
                                ),
                                if (layout.wideGuides) ...[
                                  Text(
                                    '${layout.wideOffsetMetres.toStringAsFixed(2)} m each side of centre',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Slider(
                                    value: layout.wideOffsetMetres,
                                    min: .3,
                                    max: 1.3,
                                    divisions: 20,
                                    label:
                                        '${layout.wideOffsetMetres.toStringAsFixed(2)} m',
                                    onChangeStart: setup.locked
                                        ? null
                                        : (_) => _controller.beginGesture(),
                                    onChangeEnd: setup.locked
                                        ? null
                                        : (_) => _controller.endGesture(),
                                    onChanged:
                                        setup.locked
                                            ? null
                                            : (value) => _controller.change(
                                              _controller.value.copyWith(
                                                layout: _controller.value.layout
                                                    .copyWith(
                                                      wideOffsetMetres: value,
                                                    ),
                                              ),
                                            ),
                                  ),
                                ],
                                const Divider(),
                                Text(
                                  layout.runUpMetres == 0
                                      ? 'Run-up marker · Off'
                                      : 'Run-up marker · ${layout.runUpMetres.toStringAsFixed(1)} m',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Slider(
                                  value: layout.runUpMetres,
                                  min: 0,
                                  max: 20,
                                  divisions: 40,
                                  label:
                                      '${layout.runUpMetres.toStringAsFixed(1)} m',
                                  onChangeStart: setup.locked
                                      ? null
                                      : (_) => _controller.beginGesture(),
                                  onChangeEnd: setup.locked
                                      ? null
                                      : (_) => _controller.endGesture(),
                                  onChanged:
                                      setup.locked
                                          ? null
                                          : (value) => _controller.change(
                                            _controller.value.copyWith(
                                              layout: _controller.value.layout
                                                  .copyWith(runUpMetres: value),
                                            ),
                                          ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      setup.locked
                                          ? null
                                          : () => _controller.change(
                                            setup.copyWith(
                                              endsSwapped: !setup.endsSwapped,
                                            ),
                                          ),
                                  icon: const Icon(Icons.swap_vert),
                                  label: const Text('Swap ends in diagram'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _share,
                                icon: const Icon(Icons.copy_outlined, size: 18),
                                label: const Text('Copy sizes'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: Icon(
                                  _saved
                                      ? Icons.check
                                      : Icons.bookmark_add_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _saving
                                      ? 'Saving…'
                                      : _saved
                                      ? 'Saved'
                                      : 'Save setup',
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _sharing ? null : _sharePicture,
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: Text(_sharing ? 'Preparing image…' : 'Share layout image'),
                        ),
                        TextButton(
                          onPressed: setup.locked ? null : _reset,
                          child: const Text('Reset layout'),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AR placements are estimates. Verify distances before marking. Saved dimensions stay on this phone; physical placement needs a new scan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
