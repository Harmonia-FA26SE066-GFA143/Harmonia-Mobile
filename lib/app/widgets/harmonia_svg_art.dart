import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Paths to Harmonia Web SVG illustrations declared in `pubspec.yaml`.
class HarmoniaSvgAsset {
  HarmoniaSvgAsset._();

  static const String antiphonaryGround =
      'assets/illustrations/antiphonary-ground.svg';
  static const String noResults = 'assets/illustrations/no-results.svg';
  static const String neumeSpinner = 'assets/illustrations/neume-spinner.svg';
  static const String chantIncipit = 'assets/illustrations/chant-incipit.svg';
}

/// Renders an SVG asset composed of vector primitives (`<line>`, `<rect>`, `<g>`)
/// directly from its bundled file in `assets/illustrations/`.
class HarmoniaSvgGraphic extends StatefulWidget {
  const HarmoniaSvgGraphic({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.colorOverride,
    this.skipBackgroundRect = false,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? colorOverride;
  final bool skipBackgroundRect;

  @override
  State<HarmoniaSvgGraphic> createState() => _HarmoniaSvgGraphicState();
}

class _HarmoniaSvgGraphicState extends State<HarmoniaSvgGraphic> {
  static final Map<String, _ParsedSvg> _cache = {};

  _ParsedSvg? _svg;
  AssetBundle? _bundle;
  String? _loadingPath;

  @override
  void initState() {
    super.initState();
    _svg = _cache[widget.assetPath];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bundle = DefaultAssetBundle.of(context);
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant HarmoniaSvgGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _svg = _cache[widget.assetPath];
      _loadIfNeeded();
    }
  }

  Future<void> _loadIfNeeded() async {
    final cached = _cache[widget.assetPath];
    if (cached != null) {
      if (_svg != cached && mounted) setState(() => _svg = cached);
      return;
    }
    final bundle = _bundle;
    if (bundle == null || _loadingPath == widget.assetPath) return;
    final targetPath = widget.assetPath;
    _loadingPath = targetPath;
    try {
      final raw = await bundle.loadString(targetPath);
      final parsed = _ParsedSvg.parse(raw);
      _cache[targetPath] = parsed;
      if (mounted && widget.assetPath == targetPath) {
        setState(() => _svg = parsed);
      }
    } catch (_) {
      // Leave blank silently if an optional decorative SVG asset is unavailable.
    } finally {
      if (_loadingPath == targetPath) _loadingPath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svg = _svg;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: svg == null
          ? null
          : CustomPaint(
              painter: _SvgPrimitivePainter(
                svg: svg,
                fit: widget.fit,
                alignment: widget.alignment,
                colorOverride: widget.colorOverride,
                skipBackgroundRect: widget.skipBackgroundRect,
              ),
            ),
    );
  }
}

/// Fixed warm-cream pattern layer (`antiphonary-ground.svg`) aligned to the
/// right edge behind scrollable content without intercepting pointer events or
/// obscuring descendant `Material` ink splashes.
class AntiphonaryBackground extends StatelessWidget {
  const AntiphonaryBackground({
    super.key,
    required this.child,
    this.backgroundColor,
    this.alignment = Alignment.bottomRight,
    this.opacity = 0.5,
    this.patternHeight = 195,
    this.enabled = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final Alignment alignment;
  final double opacity;
  final double patternHeight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final content = !enabled
        ? child
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: ClipRect(
                      child: Align(
                        alignment: alignment,
                        child: Opacity(
                          opacity: opacity,
                          child: SizedBox(
                            height: patternHeight,
                            width: double.infinity,
                            child: OverflowBox(
                              minWidth: patternHeight * (960 / 260),
                              maxWidth: patternHeight * (960 / 260),
                              minHeight: patternHeight,
                              maxHeight: patternHeight,
                              alignment: Alignment.centerRight,
                              child: const HarmoniaSvgGraphic(
                                assetPath: HarmoniaSvgAsset.antiphonaryGround,
                                skipBackgroundRect: true,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(type: MaterialType.transparency, child: child),
            ],
          );
    if (backgroundColor case final color?) {
      return ColoredBox(color: color, child: content);
    }
    return content;
  }
}

/// Gentle rotating neume spinner from `neume-spinner.svg` that renders statically
/// when reduced motion is enabled on the device.
class HarmoniaNeumeSpinner extends StatefulWidget {
  const HarmoniaNeumeSpinner({
    super.key,
    this.size = 30,
    this.color = AppColors.primary,
  });

  final double size;
  final Color color;

  @override
  State<HarmoniaNeumeSpinner> createState() => _HarmoniaNeumeSpinnerState();
}

class _HarmoniaNeumeSpinnerState extends State<HarmoniaNeumeSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final graphic = HarmoniaSvgGraphic(
      assetPath: HarmoniaSvgAsset.neumeSpinner,
      width: widget.size,
      height: widget.size,
      colorOverride: widget.color,
    );
    if (reduceMotion) return graphic;
    return RotationTransition(turns: _controller, child: graphic);
  }
}

class _SvgPrimitivePainter extends CustomPainter {
  _SvgPrimitivePainter({
    required this.svg,
    required this.fit,
    required this.alignment,
    required this.colorOverride,
    required this.skipBackgroundRect,
  });

  final _ParsedSvg svg;
  final BoxFit fit;
  final Alignment alignment;
  final Color? colorOverride;
  final bool skipBackgroundRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || svg.viewBox.width <= 0 || svg.viewBox.height <= 0) {
      return;
    }
    final fitted = applyBoxFit(fit, svg.viewBox.size, size);
    final dest = alignment.inscribe(fitted.destination, Offset.zero & size);
    final scaleX = dest.width / svg.viewBox.width;
    final scaleY = dest.height / svg.viewBox.height;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      dest.left - svg.viewBox.left * scaleX,
      dest.top - svg.viewBox.top * scaleY,
    );
    canvas.scale(scaleX, scaleY);

    final paint = Paint()..isAntiAlias = true;
    for (final shape in svg.shapes) {
      if (skipBackgroundRect && shape.isFullBackground(svg.viewBox)) {
        continue;
      }
      final didRotate = shape.rotationDeg != 0;
      if (didRotate) {
        canvas.save();
        canvas.translate(shape.pivotX, shape.pivotY);
        canvas.rotate(shape.rotationDeg * math.pi / 180);
        canvas.translate(-shape.pivotX, -shape.pivotY);
      }

      if (shape.fillColor != null) {
        final effectiveColor = colorOverride ?? shape.fillColor!;
        paint
          ..style = PaintingStyle.fill
          ..color = effectiveColor.withValues(
            alpha: effectiveColor.a * shape.fillOpacity,
          );
        shape.drawFill(canvas, paint);
      }

      if (shape.strokeColor != null && shape.strokeWidth > 0) {
        final effectiveColor = colorOverride ?? shape.strokeColor!;
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = shape.strokeWidth
          ..color = effectiveColor.withValues(
            alpha: effectiveColor.a * shape.strokeOpacity,
          );
        shape.drawStroke(canvas, paint);
      }

      if (didRotate) canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SvgPrimitivePainter oldDelegate) =>
      oldDelegate.svg != svg ||
      oldDelegate.fit != fit ||
      oldDelegate.alignment != alignment ||
      oldDelegate.colorOverride != colorOverride ||
      oldDelegate.skipBackgroundRect != skipBackgroundRect;
}

class _SvgStyle {
  const _SvgStyle({
    this.fillColor,
    this.fillOpacity = 1.0,
    this.strokeColor,
    this.strokeOpacity = 1.0,
    this.strokeWidth = 1.0,
  });

  final Color? fillColor;
  final double fillOpacity;
  final Color? strokeColor;
  final double strokeOpacity;
  final double strokeWidth;

  _SvgStyle applyAttributes(Map<String, String> attrs) {
    final fillRaw = attrs['fill'];
    final strokeRaw = attrs['stroke'];
    return _SvgStyle(
      fillColor: fillRaw == null ? fillColor : _parseColor(fillRaw),
      fillOpacity: _parseDouble(attrs['fill-opacity']) ?? fillOpacity,
      strokeColor: strokeRaw == null ? strokeColor : _parseColor(strokeRaw),
      strokeOpacity: _parseDouble(attrs['stroke-opacity']) ?? strokeOpacity,
      strokeWidth: _parseDouble(attrs['stroke-width']) ?? strokeWidth,
    );
  }
}

sealed class _SvgShape {
  const _SvgShape({
    required this.fillColor,
    required this.fillOpacity,
    required this.strokeColor,
    required this.strokeOpacity,
    required this.strokeWidth,
    this.rotationDeg = 0,
    this.pivotX = 0,
    this.pivotY = 0,
  });

  final Color? fillColor;
  final double fillOpacity;
  final Color? strokeColor;
  final double strokeOpacity;
  final double strokeWidth;
  final double rotationDeg;
  final double pivotX;
  final double pivotY;

  bool isFullBackground(Rect viewBox) => false;
  void drawFill(Canvas canvas, Paint paint);
  void drawStroke(Canvas canvas, Paint paint);
}

class _SvgRect extends _SvgShape {
  const _SvgRect({
    required this.rect,
    required super.fillColor,
    required super.fillOpacity,
    required super.strokeColor,
    required super.strokeOpacity,
    required super.strokeWidth,
    super.rotationDeg,
    super.pivotX,
    super.pivotY,
  });

  final Rect rect;

  @override
  bool isFullBackground(Rect viewBox) =>
      rotationDeg == 0 &&
      (rect.left - viewBox.left).abs() < 0.5 &&
      (rect.top - viewBox.top).abs() < 0.5 &&
      (rect.width - viewBox.width).abs() < 0.5 &&
      (rect.height - viewBox.height).abs() < 0.5;

  @override
  void drawFill(Canvas canvas, Paint paint) => canvas.drawRect(rect, paint);

  @override
  void drawStroke(Canvas canvas, Paint paint) => canvas.drawRect(rect, paint);
}

class _SvgLine extends _SvgShape {
  const _SvgLine({
    required this.p1,
    required this.p2,
    required super.fillColor,
    required super.fillOpacity,
    required super.strokeColor,
    required super.strokeOpacity,
    required super.strokeWidth,
  });

  final Offset p1;
  final Offset p2;

  @override
  void drawFill(Canvas canvas, Paint paint) {}

  @override
  void drawStroke(Canvas canvas, Paint paint) => canvas.drawLine(p1, p2, paint);
}

class _ParsedSvg {
  const _ParsedSvg({required this.viewBox, required this.shapes});

  final Rect viewBox;
  final List<_SvgShape> shapes;

  static final RegExp _tagPattern = RegExp(
    r'<(/?)([a-zA-Z0-9_-]+)([^>]*)>',
    dotAll: true,
  );
  static final RegExp _attrPattern = RegExp(
    r'''([a-zA-Z0-9:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
  );
  static final RegExp _rotatePattern = RegExp(
    r'rotate\(\s*([-+]?\d*\.?\d+)(?:[,\s]+([-+]?\d*\.?\d+)[,\s]+([-+]?\d*\.?\d+))?\s*\)',
  );

  static _ParsedSvg parse(String raw) {
    var viewBox = const Rect.fromLTWH(0, 0, 24, 24);
    final shapes = <_SvgShape>[];
    final styles = <_SvgStyle>[const _SvgStyle()];

    for (final match in _tagPattern.allMatches(raw)) {
      final isClosing = match.group(1) == '/';
      final tag = match.group(2)?.toLowerCase() ?? '';
      final rawAttrs = match.group(3) ?? '';
      final isSelfClosing = rawAttrs.trimRight().endsWith('/');

      if (isClosing) {
        if (tag == 'g' && styles.length > 1) styles.removeLast();
        continue;
      }

      final attrs = <String, String>{};
      for (final attrMatch in _attrPattern.allMatches(rawAttrs)) {
        final key = attrMatch.group(1);
        final val = attrMatch.group(2) ?? attrMatch.group(3) ?? '';
        if (key != null) attrs[key] = val;
      }

      if (tag == 'svg') {
        final vb = _parseViewBox(attrs['viewBox']);
        final width = _parseDouble(attrs['width']);
        final height = _parseDouble(attrs['height']);
        viewBox = vb ?? Rect.fromLTWH(0, 0, width ?? 24, height ?? 24);
        styles[0] = styles[0].applyAttributes(attrs);
        continue;
      }

      if (tag == 'g') {
        final next = styles.last.applyAttributes(attrs);
        if (!isSelfClosing) styles.add(next);
        continue;
      }

      final style = styles.last.applyAttributes(attrs);
      if (tag == 'rect') {
        final x = _parseDouble(attrs['x']) ?? 0;
        final y = _parseDouble(attrs['y']) ?? 0;
        final width = _parseDouble(attrs['width']) ?? 0;
        final height = _parseDouble(attrs['height']) ?? 0;
        if (width <= 0 || height <= 0) continue;
        final rotMatch = _rotatePattern.firstMatch(attrs['transform'] ?? '');
        final deg = _parseDouble(rotMatch?.group(1)) ?? 0;
        final cx = _parseDouble(rotMatch?.group(2)) ?? 0;
        final cy = _parseDouble(rotMatch?.group(3)) ?? 0;
        shapes.add(
          _SvgRect(
            rect: Rect.fromLTWH(x, y, width, height),
            fillColor: style.fillColor,
            fillOpacity: style.fillOpacity,
            strokeColor: style.strokeColor,
            strokeOpacity: style.strokeOpacity,
            strokeWidth: style.strokeWidth,
            rotationDeg: deg,
            pivotX: cx,
            pivotY: cy,
          ),
        );
      } else if (tag == 'line') {
        final x1 = _parseDouble(attrs['x1']) ?? 0;
        final y1 = _parseDouble(attrs['y1']) ?? 0;
        final x2 = _parseDouble(attrs['x2']) ?? 0;
        final y2 = _parseDouble(attrs['y2']) ?? 0;
        shapes.add(
          _SvgLine(
            p1: Offset(x1, y1),
            p2: Offset(x2, y2),
            fillColor: style.fillColor,
            fillOpacity: style.fillOpacity,
            strokeColor: style.strokeColor,
            strokeOpacity: style.strokeOpacity,
            strokeWidth: style.strokeWidth,
          ),
        );
      }
    }

    return _ParsedSvg(viewBox: viewBox, shapes: shapes);
  }
}

Rect? _parseViewBox(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .whereType<double>()
      .toList();
  if (parts.length != 4) return null;
  return Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
}

double? _parseDouble(String? raw) {
  if (raw == null) return null;
  final normalized = raw.trim().replaceAll('px', '');
  return double.tryParse(normalized);
}

Color? _parseColor(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty || value == 'none' || value == 'transparent') return null;
  if (!value.startsWith('#')) return null;
  final hex = value.substring(1);
  if (hex.length == 3) {
    final expanded = hex.split('').map((c) => '$c$c').join();
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
  if (hex.length == 6) {
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
  if (hex.length == 8) {
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
  return null;
}
