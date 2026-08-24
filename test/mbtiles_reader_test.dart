import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:swasthyasetu_ai/core/services/mbtiles_reader.dart';

/// What the offline map must and must not do.
///
/// The old community map documented itself as rendering "from cached MBTiles
/// when they are present" while no MBTiles reader existed anywhere in the app.
/// These tests pin the reader that now backs that claim, and — more importantly
/// — pin the negative cases: a missing tile stays missing, a corrupt pack
/// degrades instead of throwing, and a vector pack is reported as undrawable
/// rather than silently skipped.

late Directory tmp;

String _makePack({
  required String name,
  required List<(int, int, int)> xyzTiles,
  String format = 'png',
  String? bounds = '66,5,98,38',
  bool corrupt = false,
}) {
  final path = p.join(tmp.path, '$name.mbtiles');
  if (corrupt) {
    File(path).writeAsBytesSync(
        Uint8List.fromList('this is not a database'.codeUnits));
    return path;
  }
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
  db.execute('CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)');
  db.execute("INSERT INTO metadata VALUES ('name', '$name')");
  db.execute("INSERT INTO metadata VALUES ('format', '$format')");
  if (bounds != null) {
    db.execute("INSERT INTO metadata VALUES ('bounds', '$bounds')");
  }
  final stmt = db.prepare('INSERT INTO tiles VALUES (?,?,?,?)');
  for (final (z, x, y) in xyzTiles) {
    // Store in TMS row order, exactly as a real pack does.
    stmt.execute([z, x, (1 << z) - 1 - y, Uint8List.fromList([z, x, y])]);
  }
  stmt.dispose();
  db.dispose();
  return path;
}

void main() {
  setUp(() => tmp = Directory.systemTemp.createTempSync('mbtiles_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('opening a pack', () {
    test('reports the zoom range actually present, not what metadata claims',
        () {
      final path = _makePack(name: 'claims_too_much', xyzTiles: [
        (3, 5, 3),
        (4, 11, 7),
      ]);
      // A pack whose metadata lies about reaching street level.
      final db = sqlite3.open(path);
      db.execute("INSERT INTO metadata VALUES ('maxzoom', '16')");
      db.dispose();

      final reader = MbTilesReader.open(path)!;
      addTearDown(reader.close);
      expect(reader.info.minZoom, 3);
      expect(reader.info.maxZoom, 4,
          reason: 'the tiles table is the source of truth, not metadata');
      expect(reader.info.tileCount, 2);
    });

    test('a missing file returns null instead of throwing', () {
      expect(MbTilesReader.open(p.join(tmp.path, 'nope.mbtiles')), isNull);
    });

    test('a corrupt file returns null instead of throwing', () {
      final path = _makePack(name: 'junk', xyzTiles: [], corrupt: true);
      expect(MbTilesReader.open(path), isNull);
    });

    test('bounds are parsed, and an absent bounds means unknown not empty', () {
      final withBounds = MbTilesReader.open(
          _makePack(name: 'bounded', xyzTiles: [(2, 3, 1)]))!;
      addTearDown(withBounds.close);
      expect(withBounds.info.bounds, [66.0, 5.0, 98.0, 38.0]);
      expect(withBounds.info.containsPoint(22.0, 78.0), isTrue);
      expect(withBounds.info.containsPoint(51.5, -0.1), isFalse);

      final noBounds = MbTilesReader.open(
          _makePack(name: 'unbounded', xyzTiles: [(2, 3, 1)], bounds: null))!;
      addTearDown(noBounds.close);
      expect(noBounds.info.bounds, isNull);
      expect(noBounds.info.containsPoint(51.5, -0.1), isTrue,
          reason: 'unknown bounds must not be treated as covering nothing');
    });

    test('a vector pack is flagged as not drawable', () {
      final reader = MbTilesReader.open(
          _makePack(name: 'vector', xyzTiles: [(2, 3, 1)], format: 'pbf'))!;
      addTearDown(reader.close);
      expect(reader.info.isRaster, isFalse);
    });
  });

  group('tile lookup', () {
    test('XYZ y is flipped to TMS on the way in', () {
      // Written at XYZ (4, 11, 7); a reader that forgets the flip would read
      // row 7 instead of row 8 and render a mirrored world.
      final reader =
          MbTilesReader.open(_makePack(name: 'flip', xyzTiles: [(4, 11, 7)]))!;
      addTearDown(reader.close);
      expect(reader.tile(4, 11, 7), isNotNull);
      expect(reader.tile(4, 11, 8), isNull,
          reason: 'the TMS mirror of the stored tile must not resolve');
      expect(reader.tile(4, 11, 7), [4, 11, 7]);
    });

    test('a tile the pack does not hold returns null, never a placeholder', () {
      final reader =
          MbTilesReader.open(_makePack(name: 'sparse', xyzTiles: [(3, 5, 3)]))!;
      addTearDown(reader.close);
      expect(reader.tile(3, 5, 3), isNotNull);
      expect(reader.tile(3, 6, 3), isNull);
      expect(reader.tile(5, 5, 3), isNull, reason: 'zoom is out of range');
      expect(reader.tile(3, -1, 0), isNull);
      expect(reader.tile(3, 99, 0), isNull);
    });

    test('bestZoomFor picks the deepest zoom that really has the tile', () {
      // Bhopal-ish. z2 and z3 present, z4 deliberately absent.
      const lat = 23.25, lon = 77.4;
      final tiles = <(int, int, int)>[
        (2, lonToTileX(lon, 2), latToTileY(lat, 2)),
        (3, lonToTileX(lon, 3), latToTileY(lat, 3)),
        (5, 0, 0),
      ];
      final reader =
          MbTilesReader.open(_makePack(name: 'ladder', xyzTiles: tiles))!;
      addTearDown(reader.close);
      expect(reader.bestZoomFor(lat, lon, wanted: 14), 3);
    });

    test('reads survive being called after close', () {
      final reader =
          MbTilesReader.open(_makePack(name: 'closed', xyzTiles: [(2, 3, 1)]))!;
      reader.close();
      expect(reader.tile(2, 3, 1), isNull);
      reader.close(); // idempotent
    });
  });

  group('mercator projection', () {
    test('known tile coordinates', () {
      // z0 is one tile covering everything.
      expect(lonToTileX(0, 0), 0);
      expect(latToTileY(0, 0), 0);
      // The prime meridian / equator corner at z1 is the boundary of all four.
      expect(lonToTileXFractional(0, 1), closeTo(1.0, 1e-9));
      expect(latToTileYFractional(0, 1), closeTo(1.0, 1e-9));
      // India sits in the north-east quadrant at z1.
      expect(lonToTileX(77.4, 1), 1);
      expect(latToTileY(23.25, 1), 0);
      // Poles clamp rather than producing infinity: north is row 0, south is
      // the last row.
      expect(latToTileY(90, 4), 0);
      expect(latToTileY(-90, 4), 15);
    });

    test('x increases with longitude and y increases going south', () {
      expect(lonToTileXFractional(80, 6),
          greaterThan(lonToTileXFractional(70, 6)));
      expect(latToTileYFractional(10, 6),
          greaterThan(latToTileYFractional(30, 6)));
    });
  });

  group('availability', () {
    test('no packs means no tiles, and that is reportable', () {
      const empty = MapTileAvailability();
      expect(empty.hasTiles, isFalse);
      expect(empty.bestZoom, isNull);
      expect(empty.totalTiles, 0);
    });

    test('a raster pack with rows counts as coverage; a vector one does not',
        () {
      const raster = MapPackInfo(
          name: 'r',
          format: 'png',
          minZoom: 0,
          maxZoom: 6,
          tileCount: 84,
          fileBytes: 700000,
          path: 'r',
          bundled: true);
      const vector = MapPackInfo(
          name: 'v',
          format: 'pbf',
          minZoom: 0,
          maxZoom: 14,
          tileCount: 900,
          fileBytes: 1,
          path: 'v');

      expect(const MapTileAvailability(packs: [raster]).hasTiles, isTrue);
      expect(const MapTileAvailability(packs: [vector]).hasTiles, isFalse);
      expect(const MapTileAvailability(packs: [raster, vector]).bestZoom, 6,
          reason: 'an undrawable pack must not advertise its zoom depth');
      expect(const MapTileAvailability(packs: [raster]).bundledOnly, isTrue);
    });
  });

  group('bundled pack', () {
    test('the committed asset is a real, readable, raster low-zoom pack', () {
      // Guards the asset itself: a truncated or placeholder file would ship an
      // empty map that the UI would then have to lie about.
      final asset = File(p.join('assets', 'map', 'india_lowzoom.mbtiles'));
      expect(asset.existsSync(), isTrue,
          reason: 'assets/map/india_lowzoom.mbtiles is declared in pubspec');

      final reader = MbTilesReader.open(asset.path, bundled: true)!;
      addTearDown(reader.close);
      expect(reader.info.isRaster, isTrue);
      expect(reader.info.tileCount, greaterThan(20));
      expect(reader.info.minZoom, 0);
      expect(reader.info.maxZoom, greaterThanOrEqualTo(5));
      expect(reader.info.bundled, isTrue);
      expect(reader.info.attribution, contains('OpenStreetMap'));

      // Somewhere over central India must resolve at the pack's top zoom.
      final z = reader.info.maxZoom;
      expect(reader.tile(z, lonToTileX(77.4, z), latToTileY(23.25, z)),
          isNotNull);
      // The tiles are real PNGs, not stub bytes.
      final bytes = reader.tile(0, 0, 0)!;
      expect(bytes.length, greaterThan(1000));
      expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);

      // Deliberately low zoom: it is country context, not a street map.
      expect(reader.info.maxZoom, lessThanOrEqualTo(9),
          reason: 'the bundled pack must not pretend to street-level detail');
    });
  });
}
