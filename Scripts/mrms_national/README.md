# MRMS National tile worker

Mac-only. Paints NOAA `MergedReflectivityQCComposite` to XYZ PNG for DayCast Live **National radar**. The iPhone never downloads GRIB2.

```bash
cd /Users/bigstevedev/Projects/GrokCast
python3 Scripts/mrms_national/mrms_worker.py
```

Serves `http://127.0.0.1:8765/timestamps.json` and `{id}/{z}/{x}/{y}.png`. Simulator Debug builds use that URL. Device/TestFlight has no localhost — MapsGL rain is the fallback until a CDN base URL is set on `MRMSRadarService`.

Requires: `brew install eccodes` and `pip3 install --user eccodes numpy pillow`.
