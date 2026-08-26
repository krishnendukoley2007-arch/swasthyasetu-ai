import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/mbtiles_reader.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// A map drawn from tiles that are actually on this device, or an honest
/// statement that there are none.
///
/// The rule this widget exists to enforce: nothing here is drawn unless a real
/// raster tile was decoded for that square. There is no procedural "map-like"
/// background, no up-scaling of a coarse tile to fake detail, and no fallback
/// road network. A square the pack does not cover is left as plain surface
/// colour, and if no square resolves at all the caller is told so — because a
/// worker looking at an invented coastline would draw conclusions about where
/// they had been that the app cannot support.

/// One geotagged marker.
@immutable
class MapMarker {
  final double latitude;
  final double longitude;
  final Color color;

  const MapMarker({
    required this.latitude,
    required this.longitude,
    required this.color,
  });
}

/// Result of trying to render — surfaced so the card above can caption
/// accurately.
enum TileCoverage {
  /// Tiles decoded and painted.
  covered,

  /// A pack is open, but it holds nothing for this area at any zoom.
  outsidePack,

  /// No usable pack at all.
  noPack,

  /// Still opening the pack.
  loading,
}

class OfflineTileMap extends ConsumerStatefulWidget {
  final List<MapMarker> markers;

  /// Called once the widget knows what it could actually draw.
  final ValueChanged<TileCoverage>? onCoverage;

  const OfflineTileMap({super.key, required this.markers, this.onCoverage});

  @override
  ConsumerState<OfflineTileMap> createState() => _OfflineTileMapState();
}

class _OfflineTileMapState extends ConsumerState<OfflineTileMap> {
  /// Decoded images keyed by z/x/y. Decoding is async and painting is not, so
  /// tiles land here and trigger a repaint.
  final Map<String, ui.Image> _decoded = {};
  final Set<String> _decoding = {};
  TileCoverage _coverage = TileCoverage.loading;

  @override
  void dispose() {
    for (final image in _decoded.values) {
      image.dispose();
    }
    _decoded.clear();
    super.dispose();
  }

  void _report(TileCoverage coverage) {
    if (_coverage == coverage) return;
    _coverage = coverage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCoverage?.call(coverage);
    });
  }

  Future<void> _decode(String key, Uint8List bytes) async {
    if (_decoding.contains(key) || _decoded.containsKey(key)) return;
    _decoding.add(key);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _decoded[key] = frame.image);
    } catch (_) {
      // A tile that will not decode is simply not drawn.
    } finally {
      _decoding.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readerAsync = ref.watch(mapReaderProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final reader = readerAsync.valueOrNull;
        if (readerAsync.isLoading) {
          _report(TileCoverage.loading);
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (reader == null) {
          _report(TileCoverage.noPack);
          return _EmptyCanvas(markers: widget.markers, theme: theme);
        }

        final plan = _planView(
          reader,
          widget.markers,
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        if (plan == null) {
          _report(TileCoverage.outsidePack);
          return _EmptyCanvas(markers: widget.markers, theme: theme);
        }

        // Kick off decodes for anything not yet in hand. Only tiles that came
        // back non-null from the pack are ever queued.
        for (final tile in plan.tiles) {
          if (!_decoded.containsKey(tile.key)) {
            _decode(tile.key, tile.bytes);
          }
        }

        final ready = plan.tiles
            .where((t) => _decoded.containsKey(t.key))
            .map((t) => _PaintedTile(_decoded[t.key]!, t.rect))
            .toList();

        _report(ready.isEmpty ? TileCoverage.loading : TileCoverage.covered);

        return CustomPaint(
          painter: _TileMapPainter(
            tiles: ready,
            markers: plan.markerOffsets,
            background: theme.colorScheme.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Everything needed for one frame: which tiles, where they go, where the
/// markers land.
class _ViewPlan {
  final List<_TileRequest> tiles;
  final List<(Offset, Color)> markerOffsets;
  const _ViewPlan(this.tiles, this.markerOffsets);
}

class _TileRequest {
  final String key;
  final Uint8List bytes;
  final Rect rect;
  const _TileRequest(this.key, this.bytes, this.rect);
}

class _PaintedTile {
  final ui.Image image;
  final Rect rect;
  const _PaintedTile(this.image, this.rect);
}

/// Chooses the deepest zoom whose tiles the pack actually holds for the marker
/// bounding box, then lays those tiles out.
///
/// Returns null when no zoom yields a single tile — which is the difference
/// between "here is your area at low detail" and "this pack does not cover
/// where you work". Both are honest; only one is a map.
_ViewPlan? _planView(MbTilesReader reader, List<MapMarker> markers, Size size) {
  if (size.width <= 0 || size.height <= 0) return null;

  // Bounding box of the markers, with a floor so a single point does not
  // produce a zero-span window.
  double minLat, maxLat, minLon, maxLon;
  if (markers.isEmpty) {
    final b = reader.info.bounds;
    if (b == null) return null;
    minLon = b[0];
    minLat = b[1];
    maxLon = b[2];
    maxLat = b[3];
  } else {
    minLat = maxLat = markers.first.latitude;
    minLon = maxLon = markers.first.longitude;
    for (final m in markers) {
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
      if (m.longitude < minLon) minLon = m.longitude;
      if (m.longitude > maxLon) maxLon = m.longitude;
    }
    const pad = 0.02; // ~2 km, so markers are not glued to the frame edge.
    minLat -= pad;
    maxLat += pad;
    minLon -= pad;
    maxLon += pad;
  }

  const tileSize = 256.0;
  for (var z = reader.info.maxZoom; z >= reader.info.minZoom; z--) {
    final xLo = lonToTileXFractional(minLon, z);
    final xHi = lonToTileXFractional(maxLon, z);
    final yLo = latToTileYFractional(maxLat, z); // north = smaller y
    final yHi = latToTileYFractional(minLat, z);

    final spanX = (xHi - xLo).abs();
    final spanY = (yHi - yLo).abs();
    // Do not ask for a mosaic bigger than the widget can meaningfully show.
    if (spanX * tileSize > size.width * 3 || spanY * tileSize > size.height * 3) {
      continue;
    }

    // Scale so the whole box fits, then centre it.
    final scale = spanX <= 0 || spanY <= 0
        ? 1.0
        : (size.width / (spanX * tileSize))
            .clamp(0.0, size.height / (spanY * tileSize));
    final drawn = scale <= 0 ? 1.0 : scale;
    final scaledTile = tileSize * drawn;

    final originX = size.width / 2 - (xLo + xHi) / 2 * scaledTile;
    final originY = size.height / 2 - (yLo + yHi) / 2 * scaledTile;

    final firstX = xLo.floor();
    final lastX = xHi.ceil();
    final firstY = yLo.floor();
    final lastY = yHi.ceil();

    final tiles = <_TileRequest>[];
    for (var x = firstX; x <= lastX; x++) {
      for (var y = firstY; y <= lastY; y++) {
        final bytes = reader.tile(z, x, y);
        if (bytes == null) continue; // Missing stays missing.
        tiles.add(_TileRequest(
          '$z/$x/$y',
          bytes,
          Rect.fromLTWH(
            originX + x * scaledTile,
            originY + y * scaledTile,
            scaledTile,
            scaledTile,
          ),
        ));
      }
    }
    if (tiles.isEmpty) continue;

    final offsets = <(Offset, Color)>[];
    for (final m in markers) {
      offsets.add((
        Offset(
          originX + lonToTileXFractional(m.longitude, z) * scaledTile,
          originY + latToTileYFractional(m.latitude, z) * scaledTile,
        ),
        m.color,
      ));
    }
    return _ViewPlan(tiles, offsets);
  }
  return null;
}

class _TileMapPainter extends CustomPainter {
  final List<_PaintedTile> tiles;
  final List<(Offset, Color)> markers;
  final Color background;

  _TileMapPainter({
    required this.tiles,
    required this.markers,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.clipRect(Offset.zero & size);

    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final tile in tiles) {
      canvas.drawImageRect(
        tile.image,
        Rect.fromLTWH(0, 0, tile.image.width.toDouble(),
            tile.image.height.toDouble()),
        tile.rect,
        paint,
      );
    }

    for (final (offset, colour) in markers) {
      canvas.drawCircle(offset, 9, Paint()..color = colour.withValues(alpha: 0.28));
      canvas.drawCircle(offset, 4.5, Paint()..color = colour);
      canvas.drawCircle(
        offset,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_TileMapPainter old) =>
      old.tiles.length != tiles.length ||
      old.markers.length != markers.length ||
      old.background != background;
}

/// What gets drawn when there is no terrain to draw: the markers' relative
/// positions on plain surface, and nothing that could be mistaken for geography.
class _EmptyCanvas extends StatelessWidget {
  final List<MapMarker> markers;
  final ThemeData theme;

  const _EmptyCanvas({required this.markers, required this.theme});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RelativePositionPainter(
        markers: markers,
        gridColor: theme.colorScheme.outlineVariant,
        backgroundColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RelativePositionPainter extends CustomPainter {
  final List<MapMarker> markers;
  final Color gridColor;
  final Color backgroundColor;

  _RelativePositionPainter({
    required this.markers,
    required this.gridColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    if (markers.isEmpty) return;

    var minLat = markers.first.latitude, maxLat = minLat;
    var minLon = markers.first.longitude, maxLon = minLon;
    for (final m in markers) {
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
      if (m.longitude < minLon) minLon = m.longitude;
      if (m.longitude > maxLon) maxLon = m.longitude;
    }
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.001 : maxLat - minLat;
    final lonSpan = (maxLon - minLon).abs() < 0.001 ? 0.001 : maxLon - minLon;

    const inset = 12.0;
    for (final m in markers) {
      final x =
          inset + (m.longitude - minLon) / lonSpan * (size.width - inset * 2);
      // Latitude increases northward; canvas y increases downward.
      final y = size.height -
          inset -
          (m.latitude - minLat) / latSpan * (size.height - inset * 2);
      canvas.drawCircle(
          Offset(x, y), 7, Paint()..color = m.color.withValues(alpha: 0.25));
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = m.color);
    }
  }

  @override
  bool shouldRepaint(_RelativePositionPainter old) =>
      old.markers != markers || old.backgroundColor != backgroundColor;
}

/// The caption under the map. Says what the picture is, every time.
String coverageCaption(TileCoverage coverage, MapTileAvailability? packs) {
  switch (coverage) {
    case TileCoverage.loading:
      return 'Opening offline map…';
    case TileCoverage.covered:
      final pack = packs?.packs.firstOrNull;
      final detail = pack == null
          ? ''
          : ' from ${pack.name} (zoom ${pack.minZoom}–${pack.maxZoom})';
      return 'Offline tiles$detail. No patient is identified.';
    case TileCoverage.outsidePack:
      return 'Your offline pack has no tiles for this area, so positions are '
          'shown relative to each other rather than on terrain.';
    case TileCoverage.noPack:
      return 'No offline map pack on this device, so positions are shown '
          'relative to each other rather than on terrain.';
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Padding constant kept next to the map so the card and the canvas agree.
const double kMapCardRadius = AppTheme.radiusMd;
