import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:swasthyasetu_ai/core/services/storage_manager.dart';

/// Reads raster map tiles out of an MBTiles container, on device, with no
/// network.
///
/// MBTiles is just SQLite: a `tiles(zoom_level, tile_column, tile_row,
/// tile_data)` table plus a `metadata(name, value)` table. Because the app
/// already links sqlite3 for drift, reading one costs no new dependency and no
/// tile server.
///
/// The important property is honesty about coverage. A pack covers a bounding
/// box at a zoom range and nothing else; asking for a tile outside that returns
/// null rather than a placeholder, so the widget above can say "no tiles here"
/// instead of drawing terrain that was never in the file. Nothing in this class
/// invents, interpolates or up-scales a tile it does not have.

/// What a pack declares about itself, read from its `metadata` table.
@immutable
class MapPackInfo {
  /// Human-readable name from metadata, or the filename if the pack omits one.
  final String name;

  /// `png`, `jpg`, `webp`, or `pbf` for vector packs (which this reader cannot
  /// draw — see [isRaster]).
  final String format;
  final int minZoom;
  final int maxZoom;

  /// west, south, east, north in degrees. Null when the pack omits `bounds`,
  /// which is legal MBTiles and means "unknown", not "the whole world".
  final List<double>? bounds;
  final String? attribution;

  /// Actual row count in `tiles` — not a metadata claim.
  final int tileCount;
  final int fileBytes;
  final String path;

  /// True when this pack was shipped inside the APK rather than imported.
  final bool bundled;

  const MapPackInfo({
    required this.name,
    required this.format,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.fileBytes,
    required this.path,
    this.bounds,
    this.attribution,
    this.bundled = false,
  });

  /// Vector packs are valid MBTiles that this reader deliberately does not
  /// render: drawing them needs a style sheet and a vector renderer the app does
  /// not ship. Reported rather than silently ignored.
  bool get isRaster => format == 'png' || format == 'jpg' || format == 'jpeg' ||
      format == 'webp';

  bool coversZoom(int z) => z >= minZoom && z <= maxZoom;

  /// Whether a lat/lon falls inside the declared bounds. A pack with no declared
  /// bounds answers true — the tile lookup itself is then the source of truth.
  bool containsPoint(double lat, double lon) {
    final b = bounds;
    if (b == null || b.length != 4) return true;
    return lon >= b[0] && lon <= b[2] && lat >= b[1] && lat <= b[3];
  }
}

/// A pack that exists but cannot be used, and why.
@immutable
class MapPackError {
  final String path;
  final String reason;
  const MapPackError(this.path, this.reason);
}

/// Everything the UI needs to decide what to draw.
@immutable
class MapTileAvailability {
  final List<MapPackInfo> packs;
  final List<MapPackError> errors;

  const MapTileAvailability({this.packs = const [], this.errors = const []});

  bool get hasTiles => packs.any((pack) => pack.isRaster && pack.tileCount > 0);

  int get totalTiles =>
      packs.fold(0, (sum, pack) => sum + pack.tileCount);

  int get totalBytes => packs.fold(0, (sum, pack) => sum + pack.fileBytes);

  /// Highest zoom any usable pack reaches — i.e. the best detail available.
  int? get bestZoom {
    final usable = packs.where((pack) => pack.isRaster && pack.tileCount > 0);
    if (usable.isEmpty) return null;
    return usable.map((pack) => pack.maxZoom).reduce((a, b) => a > b ? a : b);
  }

  bool get bundledOnly =>
      packs.isNotEmpty && packs.every((pack) => pack.bundled);
}

class MbTilesReader {
  MbTilesReader._(this._db, this.info);

  final Database _db;
  final MapPackInfo info;

  /// Small LRU-ish cache. A tile is ~10-40 KB and one screen shows at most a
  /// couple of dozen, so a flat cap is enough; without it every repaint would
  /// hit SQLite for the same rows.
  final Map<int, Uint8List?> _cache = {};
  static const int _cacheLimit = 128;

  bool _closed = false;

  /// Opens a pack read-only. Returns null and never throws when the file is
  /// missing, truncated, or not MBTiles at all — a corrupt download must not
  /// take the dashboard down with it.
  static MbTilesReader? open(String path, {bool bundled = false}) {
    Database? db;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      db = sqlite3.open(path, mode: OpenMode.readOnly);

      final meta = <String, String>{};
      for (final row in db.select('SELECT name, value FROM metadata')) {
        final name = row['name'];
        final value = row['value'];
        if (name is String && value != null) meta[name] = value.toString();
      }

      final zooms = db.select(
          'SELECT MIN(zoom_level) AS lo, MAX(zoom_level) AS hi, '
          'COUNT(*) AS n FROM tiles');
      final row = zooms.first;
      final count = (row['n'] as int?) ?? 0;
      // Trust the table over the metadata: a pack whose metadata claims z0-14
      // but only holds z0-6 must not be advertised as street-level.
      final minZoom = (row['lo'] as int?) ??
          int.tryParse(meta['minzoom'] ?? '') ?? 0;
      final maxZoom = (row['hi'] as int?) ??
          int.tryParse(meta['maxzoom'] ?? '') ?? 0;

      final info = MapPackInfo(
        name: meta['name']?.trim().isNotEmpty == true
            ? meta['name']!.trim()
            : p.basenameWithoutExtension(path),
        format: (meta['format'] ?? 'png').toLowerCase().trim(),
        minZoom: minZoom,
        maxZoom: maxZoom,
        bounds: _parseBounds(meta['bounds']),
        attribution: meta['attribution'],
        tileCount: count,
        fileBytes: file.lengthSync(),
        path: path,
        bundled: bundled,
      );
      return MbTilesReader._(db, info);
    } catch (_) {
      db?.dispose();
      return null;
    }
  }

  static List<double>? _parseBounds(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 4) return null;
    final values = <double>[];
    for (final part in parts) {
      final v = double.tryParse(part.trim());
      if (v == null) return null;
      values.add(v);
    }
    return values;
  }

  /// Raw tile bytes in XYZ (Google/Slippy) coordinates, or null when the pack
  /// simply does not contain that tile.
  ///
  /// MBTiles stores rows in TMS order — y counted up from the south — so the
  /// row is flipped here. Getting this backwards renders a vertically mirrored
  /// world, which is exactly the kind of plausible-looking wrong output this
  /// codebase is trying to stop shipping.
  Uint8List? tile(int z, int x, int y) {
    if (_closed) return null;
    if (!info.coversZoom(z)) return null;
    final span = 1 << z;
    if (x < 0 || y < 0 || x >= span || y >= span) return null;

    final key = (z << 42) ^ (x << 21) ^ y;
    if (_cache.containsKey(key)) return _cache[key];

    Uint8List? bytes;
    try {
      final rows = _db.select(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? '
        'AND tile_row = ? LIMIT 1',
        [z, x, span - 1 - y],
      );
      if (rows.isNotEmpty) {
        final blob = rows.first['tile_data'];
        if (blob is Uint8List) bytes = blob;
        if (blob is List<int>) bytes = Uint8List.fromList(blob);
      }
    } catch (_) {
      bytes = null;
    }

    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[key] = bytes;
    return bytes;
  }

  /// Deepest zoom at or below [wanted] that actually holds the tile covering
  /// [lat]/[lon]. Used to pick a zoom the pack can really serve rather than
  /// requesting one it cannot and drawing holes.
  int? bestZoomFor(double lat, double lon, {int wanted = 14}) {
    for (var z = wanted.clamp(info.minZoom, info.maxZoom);
        z >= info.minZoom;
        z--) {
      final x = lonToTileX(lon, z);
      final y = latToTileY(lat, z);
      if (tile(z, x, y) != null) return z;
    }
    return null;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    _db.dispose();
  }
}

// ───────────────────────── Web Mercator helpers ─────────────────────────
// Fractional variants are what the overlay needs: a marker sits somewhere
// inside a tile, not on its corner.

double lonToTileXFractional(double lon, int z) =>
    (lon + 180.0) / 360.0 * (1 << z);

double latToTileYFractional(double lat, int z) {
  final clamped = lat.clamp(-85.05112878, 85.05112878);
  final rad = clamped * math.pi / 180.0;
  return (1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) /
      2.0 *
      (1 << z);
}

int lonToTileX(double lon, int z) =>
    lonToTileXFractional(lon, z).floor().clamp(0, (1 << z) - 1);

int latToTileY(double lat, int z) =>
    latToTileYFractional(lat, z).floor().clamp(0, (1 << z) - 1);

// ───────────────────────────── Pack discovery ─────────────────────────────

/// The pack shipped inside the APK. Real OpenStreetMap raster tiles, zoom 0-6
/// over the subcontinent — country-level context, roughly 690 KB. It exists so
/// the map is never a blank grey rectangle offline; it is not, and does not
/// claim to be, a street map.
const String kBundledPackAsset = 'assets/map/india_lowzoom.mbtiles';
const String kBundledPackFileName = 'bundled_india_lowzoom.mbtiles';

/// Copies the bundled pack out of the APK into the tiles directory, once.
///
/// sqlite3 needs a real file descriptor, and an asset is not one. Re-copies if
/// the on-disk size does not match the asset, which is how an app upgrade with a
/// new pack takes effect.
Future<File?> materializeBundledPack() async {
  try {
    final data = await rootBundle.load(kBundledPackAsset);
    final dir = await StorageManager.mapTilesDirectory();
    final file = File(p.join(dir.path, kBundledPackFileName));
    final expected = data.lengthInBytes;
    if (await file.exists() && await file.length() == expected) return file;
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, expected),
      flush: true,
    );
    return file;
  } catch (_) {
    // No bundled pack in this build, or the directory is not writable. Both are
    // survivable: the UI falls back to its no-tiles state.
    return null;
  }
}

/// Every `.mbtiles` in the tiles directory, opened and inspected.
///
/// Imported packs sort ahead of the bundled one so a worker who has copied in a
/// district pack gets its detail rather than the low-zoom fallback.
Future<MapTileAvailability> discoverMapPacks() async {
  final packs = <MapPackInfo>[];
  final errors = <MapPackError>[];
  try {
    await materializeBundledPack();
    final dir = await StorageManager.mapTilesDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.mbtiles')
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final bundled = p.basename(file.path) == kBundledPackFileName;
      final reader = MbTilesReader.open(file.path, bundled: bundled);
      if (reader == null) {
        errors.add(MapPackError(file.path, 'not a readable MBTiles file'));
        continue;
      }
      final info = reader.info;
      reader.close();
      if (info.tileCount == 0) {
        errors.add(MapPackError(file.path, 'contains no tiles'));
        continue;
      }
      if (!info.isRaster) {
        errors.add(MapPackError(
            file.path, 'vector (${info.format}) packs cannot be drawn'));
        continue;
      }
      packs.add(info);
    }
  } catch (e) {
    errors.add(MapPackError('map_tiles', 'could not be listed: $e'));
  }

  packs.sort((a, b) {
    if (a.bundled != b.bundled) return a.bundled ? 1 : -1;
    return b.maxZoom.compareTo(a.maxZoom);
  });
  return MapTileAvailability(packs: packs, errors: errors);
}
