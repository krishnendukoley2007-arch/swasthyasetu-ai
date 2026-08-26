"""Build the bundled low-zoom offline map pack.

Fetches real raster tiles from openstreetmap.org for the Indian subcontinent at
zooms 0-6 and writes them into a standard MBTiles (SQLite) container. Low zoom
only, on purpose: it is ~50 tiles / <1 MB, it gives a worker country-level
context for where their screenings sit, and it does not pretend to be a
navigable street map. Higher zooms are the job of an imported pack.

Run from the repo root:  python tool/build_map_pack.py
The output is committed as assets/map/india_lowzoom.mbtiles; this script only
needs re-running when the bbox or zoom range changes.
"""

import math
import os
import sqlite3
import time
import urllib.request

OUT = os.path.join('assets', 'map', 'india_lowzoom.mbtiles')
# Indian subcontinent, generous margin: west, south, east, north.
BOUNDS = (66.0, 5.0, 98.0, 38.0)
ZOOMS = range(0, 7)
UA = 'SwasthyaSetuAI/1.0 (offline health screening; low-zoom pack build)'


def lon_to_x(lon, z):
    return int((lon + 180.0) / 360.0 * (1 << z))


def lat_to_y(lat, z):
    rad = math.radians(lat)
    return int(
        (1.0 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi)
        / 2.0 * (1 << z)
    )


def fetch(z, x, y):
    url = 'https://tile.openstreetmap.org/{}/{}/{}.png'.format(z, x, y)
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript(
        """
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (
          zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER,
          tile_data BLOB);
        CREATE UNIQUE INDEX tile_index
          ON tiles (zoom_level, tile_column, tile_row);
        """
    )
    west, south, east, north = BOUNDS
    total = 0
    for z in ZOOMS:
        x0, x1 = lon_to_x(west, z), lon_to_x(east, z)
        y0, y1 = lat_to_y(north, z), lat_to_y(south, z)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                try:
                    blob = fetch(z, x, y)
                except Exception as exc:  # noqa: BLE001 - report and continue
                    print('skip {}/{}/{}: {}'.format(z, x, y, exc))
                    continue
                # MBTiles rows are TMS: y counted from the south.
                tms_y = (1 << z) - 1 - y
                db.execute(
                    'INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)',
                    (z, x, tms_y, blob),
                )
                total += 1
                time.sleep(0.12)
        db.commit()
        print('z{} done, {} tiles so far'.format(z, total))

    meta = [
        ('name', 'India low-zoom (bundled)'),
        ('format', 'png'),
        ('minzoom', str(min(ZOOMS))),
        ('maxzoom', str(max(ZOOMS))),
        ('bounds', '{},{},{},{}'.format(*BOUNDS)),
        ('type', 'baselayer'),
        ('version', '1'),
        ('attribution', '(c) OpenStreetMap contributors'),
        ('description',
         'Country-level context only. Bundled with the app so the map is not '
         'blank offline; import a regional pack for street-level detail.'),
    ]
    db.executemany('INSERT INTO metadata VALUES (?,?)', meta)
    db.commit()
    db.close()
    print('wrote {} ({} tiles, {:.0f} KB)'.format(
        OUT, total, os.path.getsize(OUT) / 1024))


if __name__ == '__main__':
    main()
