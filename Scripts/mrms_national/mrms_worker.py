#!/usr/bin/env python3
"""Mac worker: NOAA MRMS MergedReflectivityQCComposite → XYZ PNG + timestamps.

Phone never downloads GRIB2. Simulator hits http://127.0.0.1:8765.

  python3 Scripts/mrms_national/mrms_worker.py
  python3 Scripts/mrms_national/mrms_worker.py --once --no-serve

NWS 5 dBZ LUT copied from MapsGLRadarPalette. Nearest resample. 0 dBZ alpha 0.
"""
from __future__ import annotations

import argparse
import gzip
import json
import math
import os
import re
import shutil
import sys
import threading
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

import numpy as np
from PIL import Image

import eccodes

# MapsGLRadarPalette.reflectivityStops — stepped 5 dBZ, 0 transparent.
STOPS = [
    (0, (0x00, 0xEC, 0xEC, 0)),
    (5, (0x01, 0xA0, 0xF6, int(0.85 * 255))),
    (10, (0x00, 0x00, 0xF6, int(0.90 * 255))),
    (15, (0x00, 0xFF, 0x00, int(0.94 * 255))),
    (20, (0x00, 0xC8, 0x00, int(0.97 * 255))),
    (25, (0x00, 0x90, 0x00, 255)),
    (30, (0xFF, 0xFF, 0x00, 255)),
    (35, (0xE7, 0xC0, 0x00, 255)),
    (40, (0xFF, 0x90, 0x00, 255)),
    (45, (0xFF, 0x00, 0x00, 255)),
    (50, (0xD6, 0x00, 0x00, 255)),
    (55, (0xC0, 0x00, 0x00, 255)),
    (60, (0xFF, 0x00, 0xFF, 255)),
    (65, (0x99, 0x55, 0xC9, 255)),
    (70, (0xFF, 0xFF, 0xFF, 255)),
]

LUT_R = np.zeros(15, dtype=np.uint8)
LUT_G = np.zeros(15, dtype=np.uint8)
LUT_B = np.zeros(15, dtype=np.uint8)
LUT_A = np.zeros(15, dtype=np.uint8)
for i, (_, rgba) in enumerate(STOPS):
    LUT_R[i], LUT_G[i], LUT_B[i], LUT_A[i] = rgba

ORIGIN_SHIFT = 20037508.342789244
UA = "DayCast/1.0 MRMS-worker (https://daycast.app)"
NCEP_DIR = "https://mrms.ncep.noaa.gov/2D/MergedReflectivityQCComposite/"
LATEST_NAME = "MRMS_MergedReflectivityQCComposite.latest.grib2.gz"
TS_RE = re.compile(
    r"MRMS_MergedReflectivityQCComposite_00\.50_(\d{8}-\d{6})\.grib2\.gz"
)
EMPTY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
    b"\x00\x00\x05\x00\x01\r\n\x2d\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)


def lon_to_x(lon):
    return lon * ORIGIN_SHIFT / 180.0


def lat_to_y(lat):
    lat = np.clip(lat, -85.05112878, 85.05112878)
    return np.log(np.tan((90.0 + lat) * math.pi / 360.0)) / (math.pi / 180.0) * ORIGIN_SHIFT / 180.0


def x_to_lon(x):
    return x * 180.0 / ORIGIN_SHIFT


def y_to_lat(y):
    return (180.0 / math.pi) * (2.0 * np.arctan(np.exp(y * math.pi / ORIGIN_SHIFT)) - math.pi / 2.0)


def lonlat_to_tile(lon, lat, z):
    n = 2.0 ** z
    x = int((lon + 180.0) / 360.0 * n)
    lat_r = math.radians(lat)
    y = int((1.0 - math.log(math.tan(lat_r) + 1.0 / math.cos(lat_r)) / math.pi) / 2.0 * n)
    return x, y


def tile_xy_to_merc(z, x, y):
    n = 2.0 ** z
    west = x / n * 2 * ORIGIN_SHIFT - ORIGIN_SHIFT
    east = (x + 1) / n * 2 * ORIGIN_SHIFT - ORIGIN_SHIFT
    north = ORIGIN_SHIFT - y / n * 2 * ORIGIN_SHIFT
    south = ORIGIN_SHIFT - (y + 1) / n * 2 * ORIGIN_SHIFT
    return west, south, east, north


def colorize_dbz(dbz):
    bins = np.zeros(dbz.shape, dtype=np.int16)
    valid = np.isfinite(dbz) & (dbz >= 5.0) & (dbz < 9000)
    bins[valid] = np.clip((dbz[valid] // 5).astype(np.int16), 0, 14)
    rgba = np.zeros(dbz.shape + (4,), dtype=np.uint8)
    rgba[..., 0] = LUT_R[bins]
    rgba[..., 1] = LUT_G[bins]
    rgba[..., 2] = LUT_B[bins]
    rgba[..., 3] = LUT_A[bins]
    transparent = rgba[..., 3] == 0
    rgba[transparent] = 0
    return rgba


def sample_dbz(grid, west_lon, north_lat, dlon, dlat, lons, lats):
    cols = np.rint((lons - west_lon) / dlon).astype(np.int32)
    rows = np.rint((north_lat - lats) / dlat).astype(np.int32)
    nj, ni = grid.shape
    valid = (cols >= 0) & (cols < ni) & (rows >= 0) & (rows < nj)
    out = np.full(lons.shape, np.nan, dtype=np.float32)
    out[valid] = grid[rows[valid], cols[valid]]
    return out


def reproject_mercator(grid, west_lon, south_lat, east_lon, north_lat, dlon, dlat, width):
    x0, x1 = lon_to_x(west_lon), lon_to_x(east_lon)
    y0, y1 = lat_to_y(south_lat), lat_to_y(north_lat)
    height = max(1, int(round(width * (y1 - y0) / (x1 - x0))))
    xs = np.linspace(x0, x1, width, endpoint=False) + (x1 - x0) / (2 * width)
    ys = np.linspace(y1, y0, height, endpoint=False) - (y1 - y0) / (2 * height)
    xx, yy = np.meshgrid(xs, ys)
    dbz = sample_dbz(grid, west_lon, north_lat, dlon, dlat, x_to_lon(xx), y_to_lat(yy))
    rgba = colorize_dbz(dbz)
    return rgba, x0, y0, x1, y1


def load_grib(path):
    with open(path, "rb") as f:
        gid = eccodes.codes_grib_new_from_file(f)
        if gid is None:
            raise RuntimeError(f"no GRIB message in {path}")
        ni = eccodes.codes_get(gid, "Ni")
        nj = eccodes.codes_get(gid, "Nj")
        lat1 = eccodes.codes_get(gid, "latitudeOfFirstGridPointInDegrees")
        lon1 = eccodes.codes_get(gid, "longitudeOfFirstGridPointInDegrees")
        lat2 = eccodes.codes_get(gid, "latitudeOfLastGridPointInDegrees")
        lon2 = eccodes.codes_get(gid, "longitudeOfLastGridPointInDegrees")
        dlon = eccodes.codes_get(gid, "iDirectionIncrementInDegrees")
        dlat = eccodes.codes_get(gid, "jDirectionIncrementInDegrees")
        year = eccodes.codes_get(gid, "year")
        month = eccodes.codes_get(gid, "month")
        day = eccodes.codes_get(gid, "day")
        hour = eccodes.codes_get(gid, "hour")
        minute = eccodes.codes_get(gid, "minute")
        second = eccodes.codes_get(gid, "second")
        values = eccodes.codes_get_values(gid)
        eccodes.codes_release(gid)
    grid = np.asarray(values, dtype=np.float32).reshape((nj, ni))
    west = lon1 if lon1 <= 180 else lon1 - 360
    east = lon2 if lon2 <= 180 else lon2 - 360
    north = lat1
    south = lat2
    valid_time = datetime(year, month, day, hour, minute, second, tzinfo=timezone.utc)
    return grid, west, south, east, north, dlon, dlat, valid_time


def frame_id_from_dt(dt: datetime) -> str:
    return dt.strftime("%Y%m%d-%H%M%S")


def parse_listing_ts(token: str) -> datetime:
    return datetime.strptime(token, "%Y%m%d-%H%M%S").replace(tzinfo=timezone.utc)


def fetch_bytes(url: str, timeout: int = 40) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def list_ncep_frames(window: timedelta) -> list[tuple[datetime, str]]:
    html = fetch_bytes(NCEP_DIR, timeout=30).decode("utf-8", errors="replace")
    now = datetime.now(timezone.utc)
    found: dict[str, datetime] = {}
    for match in TS_RE.finditer(html):
        token = match.group(1)
        dt = parse_listing_ts(token)
        if now - dt <= window:
            found[token] = dt
    frames = [(dt, f"MRMS_MergedReflectivityQCComposite_00.50_{token}.grib2.gz") for token, dt in found.items()]
    frames.sort(key=lambda item: item[0])
    return frames


def gunzip_to(src_gz: str, dest: str) -> None:
    with gzip.open(src_gz, "rb") as gz, open(dest, "wb") as out:
        shutil.copyfileobj(gz, out)


def write_png(path: str, rgba: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(path, "PNG", optimize=True)


def cut_tiles(rgba: np.ndarray, x0, y0, x1, y1, zooms, extra_bboxes, dest_root: str) -> int:
    """Cut 256px XYZ tiles from a mercator overlay. Skip fully transparent tiles."""
    overlay = Image.fromarray(rgba, "RGBA")
    ow, oh = overlay.size
    written = 0
    jobs = []
    for z in zooms:
        tx0, ty0 = lonlat_to_tile(x_to_lon(x0) + 0.05, y_to_lat(y1) - 0.05, z)
        tx1, ty1 = lonlat_to_tile(x_to_lon(x1) - 0.05, y_to_lat(y0) + 0.05, z)
        jobs.append((z, min(tx0, tx1), max(tx0, tx1), min(ty0, ty1), max(ty0, ty1)))
    for z, bbox in extra_bboxes:
        w, s, e, n = bbox
        ax, ay = lonlat_to_tile(w, n, z)
        bx, by = lonlat_to_tile(e, s, z)
        jobs.append((z, min(ax, bx), max(ax, bx), min(ay, by), max(ay, by)))

    n_max = {}
    for z, xmin, xmax, ymin, ymax in jobs:
        cap = (1 << z) - 1
        xmin, xmax = max(0, xmin), min(cap, xmax)
        ymin, ymax = max(0, ymin), min(cap, ymax)
        key = z
        prev = n_max.get(key)
        if prev is None:
            n_max[key] = [xmin, xmax, ymin, ymax]
        else:
            prev[0] = min(prev[0], xmin)
            prev[1] = max(prev[1], xmax)
            prev[2] = min(prev[2], ymin)
            prev[3] = max(prev[3], ymax)

    dx = x1 - x0
    dy = y1 - y0
    for z, (xmin, xmax, ymin, ymax) in n_max.items():
        for x in range(xmin, xmax + 1):
            for y in range(ymin, ymax + 1):
                mw, ms, me, mn = tile_xy_to_merc(z, x, y)
                px0 = (mw - x0) / dx * ow
                px1 = (me - x0) / dx * ow
                py0 = (y1 - mn) / dy * oh
                py1 = (y1 - ms) / dy * oh
                left, right = int(math.floor(px0)), int(math.ceil(px1))
                top, bottom = int(math.floor(py0)), int(math.ceil(py1))
                if right <= 0 or bottom <= 0 or left >= ow or top >= oh:
                    continue
                left = max(0, left)
                top = max(0, top)
                right = min(ow, right)
                bottom = min(oh, bottom)
                if right - left < 1 or bottom - top < 1:
                    continue
                crop = overlay.crop((left, top, right, bottom))
                tile = crop.resize((256, 256), Image.NEAREST)
                extrema = tile.getextrema()
                if extrema is None or extrema[3][1] == 0:
                    continue
                path = os.path.join(dest_root, str(z), str(x), f"{y}.png")
                os.makedirs(os.path.dirname(path), exist_ok=True)
                tile.save(path, "PNG", optimize=True)
                written += 1
        print(f"    z{z} x {xmin}-{xmax} y {ymin}-{ymax}", flush=True)
    return written


def paint_frame(grib_path: str, out_root: str, overlay_width: int, zooms, extra_bboxes) -> dict:
    grid, west, south, east, north, dlon, dlat, valid_time = load_grib(grib_path)
    fid = frame_id_from_dt(valid_time)
    dest = os.path.join(out_root, fid)
    marker = os.path.join(dest, ".done")
    if os.path.exists(marker):
        return {"id": fid, "t": valid_time.strftime("%Y-%m-%dT%H:%M:%SZ"), "skipped": True}

    print(f"  paint {fid} grid {grid.shape}", flush=True)
    rgba, x0, y0, x1, y1 = reproject_mercator(
        grid, west, south, east, north, dlon, dlat, width=overlay_width
    )
    os.makedirs(dest, exist_ok=True)
    write_png(os.path.join(dest, "overlay.png"), rgba)
    n_tiles = cut_tiles(rgba, x0, y0, x1, y1, zooms, extra_bboxes, dest)
    meta = {
        "id": fid,
        "t": valid_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tiles": n_tiles,
        "overlayWidth": int(rgba.shape[1]),
        "overlayHeight": int(rgba.shape[0]),
    }
    with open(os.path.join(dest, "frame.json"), "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    with open(marker, "w") as f:
        f.write(fid + "\n")
    print(f"  wrote {n_tiles} tiles for {fid}", flush=True)
    return meta


def write_timestamps(out_root: str, public_base: str, window: timedelta) -> dict:
    now = datetime.now(timezone.utc)
    frames = []
    for name in os.listdir(out_root):
        dest = os.path.join(out_root, name)
        marker = os.path.join(dest, ".done")
        meta_path = os.path.join(dest, "frame.json")
        if not os.path.isdir(dest) or not os.path.exists(marker):
            continue
        if os.path.exists(meta_path):
            with open(meta_path) as f:
                meta = json.load(f)
            t = datetime.strptime(meta["t"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        else:
            t = parse_listing_ts(name)
            meta = {"id": name, "t": t.strftime("%Y-%m-%dT%H:%M:%SZ")}
        if now - t > window:
            continue
        frames.append(
            {
                "t": meta["t"],
                "id": meta["id"],
                "template": f"{public_base.rstrip('/')}/{meta['id']}/{{z}}/{{x}}/{{y}}.png",
            }
        )
    frames.sort(key=lambda item: item["t"], reverse=True)
    payload = {
        "product": "national",
        "source": "NOAA MRMS MergedReflectivityQCComposite",
        "updated": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "frames": frames,
    }
    tmp = os.path.join(out_root, "timestamps.json.tmp")
    dest = os.path.join(out_root, "timestamps.json")
    with open(tmp, "w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    os.replace(tmp, dest)
    return payload


def prune_old(out_root: str, keep: timedelta) -> None:
    now = datetime.now(timezone.utc)
    for name in os.listdir(out_root):
        dest = os.path.join(out_root, name)
        if not os.path.isdir(dest):
            continue
        try:
            dt = parse_listing_ts(name)
        except ValueError:
            continue
        if now - dt > keep:
            shutil.rmtree(dest, ignore_errors=True)
            print(f"  pruned {name}", flush=True)


def download_grib(url: str, dest_gz: str, dest_grib: str) -> None:
    os.makedirs(os.path.dirname(dest_gz), exist_ok=True)
    data = fetch_bytes(url, timeout=60)
    with open(dest_gz, "wb") as f:
        f.write(data)
    gunzip_to(dest_gz, dest_grib)


class TileHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory=None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write("[mrms-http] " + (fmt % args) + "\n")

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "public, max-age=60")
        super().end_headers()

    def do_GET(self):
        if self.path in ("/", "/health"):
            body = b"ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        # Missing tiles → 1x1 transparent so Mapbox does not spam errors.
        parsed = self.path.split("?")[0]
        if parsed.endswith(".png"):
            fs_path = self.translate_path(parsed)
            if not os.path.exists(fs_path):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(EMPTY_PNG)))
                self.end_headers()
                self.wfile.write(EMPTY_PNG)
                return
        return super().do_GET()


def start_server(directory: str, port: int) -> ThreadingHTTPServer:
    handler = lambda *args, **kwargs: TileHandler(*args, directory=directory, **kwargs)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    print(f"serving http://127.0.0.1:{port} from {directory}", flush=True)
    return httpd


def run_tick(args) -> dict:
    window = timedelta(minutes=args.window_minutes)
    src_dir = os.path.join(args.out, "src")
    os.makedirs(src_dir, exist_ok=True)
    extra = [(7, bbox) for bbox in args.z7_bboxes]

    listed = list_ncep_frames(window + timedelta(minutes=4))
    print(f"ncep listed {len(listed)} frames in window", flush=True)

    # Always ingest .latest — valid time from GRIB, not the listing clock.
    latest_gz = os.path.join(src_dir, LATEST_NAME)
    latest_grib = latest_gz[: -len(".gz")]
    try:
        download_grib(NCEP_DIR + LATEST_NAME, latest_gz, latest_grib)
        latest_meta = paint_frame(
            latest_grib, args.out, args.overlay_width, args.zooms, extra
        )
        print(f"latest {latest_meta.get('t')} skipped={latest_meta.get('skipped', False)}", flush=True)
    except Exception as exc:
        print(f"latest failed: {exc}", flush=True)

    # Cap to newest N so first backfill stays ~1h even if listing is generous.
    listed = listed[-args.max_frames :]
    for dt, name in listed:
        fid = frame_id_from_dt(dt)
        if os.path.exists(os.path.join(args.out, fid, ".done")):
            continue
        gz = os.path.join(src_dir, name)
        grib = gz[: -len(".gz")]
        url = NCEP_DIR + name
        try:
            print(f"fetch {name}", flush=True)
            download_grib(url, gz, grib)
            paint_frame(grib, args.out, args.overlay_width, args.zooms, extra)
        except Exception as exc:
            print(f"frame {name} failed: {exc}", flush=True)

    prune_old(args.out, window + timedelta(minutes=10))
    payload = write_timestamps(args.out, args.public_base, window)
    print(f"timestamps {len(payload['frames'])} frames newest={payload['frames'][0]['t'] if payload['frames'] else 'none'}", flush=True)
    return payload


def parse_args(argv):
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    default_out = os.path.join(repo, "scratch", "radar-mrms-live-2026-08-22", "out")
    p = argparse.ArgumentParser(description="Paint NOAA MRMS national tiles for DayCast Live.")
    p.add_argument("--out", default=default_out)
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--interval", type=int, default=120, help="Loop seconds")
    p.add_argument("--window-minutes", type=int, default=60)
    p.add_argument("--max-frames", type=int, default=32)
    p.add_argument("--overlay-width", type=int, default=4096)
    p.add_argument("--zooms", default="3,4,5,6")
    p.add_argument("--once", action="store_true")
    p.add_argument("--no-serve", action="store_true")
    p.add_argument("--public-base", default="http://127.0.0.1:8765")
    args = p.parse_args(argv)
    args.zooms = [int(z) for z in args.zooms.split(",") if z.strip()]
    # z7 regional: Gulf/Florida + Memphis/Olive Branch so dry-open zoom-in still has tiles.
    args.z7_bboxes = [
        (-95.0, 24.0, -79.0, 32.5),
        (-93.5, 33.5, -86.5, 37.5),
    ]
    return args


def main(argv=None) -> int:
    args = parse_args(argv or sys.argv[1:])
    os.makedirs(args.out, exist_ok=True)
    httpd = None
    if not args.no_serve:
        httpd = start_server(args.out, args.port)
    run_tick(args)
    if args.once:
        if httpd is None:
            return 0
        print("serving until Ctrl-C", flush=True)
        try:
            while True:
                time.sleep(3600)
        except KeyboardInterrupt:
            return 0
    while True:
        time.sleep(args.interval)
        try:
            run_tick(args)
        except Exception as exc:
            print(f"tick failed: {exc}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
