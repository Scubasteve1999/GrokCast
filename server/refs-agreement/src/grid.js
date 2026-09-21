/** Nearest i,j on the REFS domain grids. Verified against eccodes nearest-neighbor. */

const DEG = Math.PI / 180;

function eastLongitude(lon) {
  let value = lon;
  while (value < 0) value += 360;
  while (value >= 360) value -= 360;
  return value;
}

function lambertCone(latin1, latin2) {
  const phi1 = latin1 * DEG;
  const phi2 = latin2 * DEG;
  if (Math.abs(phi1 - phi2) < 1e-6) return Math.sin(phi1);
  const num = Math.log(Math.cos(phi1) / Math.cos(phi2));
  const den = Math.log(
    Math.tan(Math.PI / 4 + phi2 / 2) / Math.tan(Math.PI / 4 + phi1 / 2),
  );
  return num / den;
}

function projectLambert(grid, lat, lon) {
  const n = lambertCone(grid.latin1, grid.latin2);
  const latin = grid.latin1;
  const factor =
    (Math.cos(latin * DEG) * Math.tan(Math.PI / 4 + (latin * DEG) / 2) ** n) / n;
  const rho = (la) =>
    (grid.radius * factor) / Math.tan(Math.PI / 4 + (la * DEG) / 2) ** n;
  const theta = (lo) => n * (lo - grid.lov) * DEG;
  const east = eastLongitude(lon);
  const x = rho(lat) * Math.sin(theta(east));
  const y = rho(lat) * Math.cos(theta(east));
  const x1 = rho(grid.lat1) * Math.sin(theta(grid.lon1));
  const y1 = rho(grid.lat1) * Math.cos(theta(grid.lon1));
  return { i: (x - x1) / grid.dx, j: (y1 - y) / grid.dy };
}

function projectMercator(grid, lat, lon) {
  const scale = Math.cos(grid.lad * DEG);
  const east = eastLongitude(lon);
  const x = grid.radius * scale * (east - grid.lon1) * DEG;
  const y =
    grid.radius *
    scale *
    Math.log(
      Math.tan(Math.PI / 4 + (lat * DEG) / 2) /
        Math.tan(Math.PI / 4 + (grid.lat1 * DEG) / 2),
    );
  return { i: x / grid.dx, j: y / grid.dy };
}

function projectPolar(grid, lat, lon) {
  const south = (grid.projectionCenter & 0x80) !== 0;
  const sign = south ? -1 : 1;
  const lad = grid.lad * DEG;
  const rho = (la) =>
    grid.radius * (1 + Math.sin(sign * lad)) * Math.tan(Math.PI / 4 - (sign * la * DEG) / 2);
  const east = eastLongitude(lon);
  const theta = (lo) => (lo - grid.lov) * DEG;
  const x = rho(lat) * Math.sin(theta(east));
  const y = rho(lat) * Math.cos(theta(east));
  const x1 = rho(grid.lat1) * Math.sin(theta(grid.lon1));
  const y1 = rho(grid.lat1) * Math.cos(theta(grid.lon1));
  return { i: (x - x1) / grid.dx, j: (y1 - y) / grid.dy };
}

export function gridIndex(grid, lat, lon) {
  let projected;
  if (grid.kind === "lambert") projected = projectLambert(grid, lat, lon);
  else if (grid.kind === "mercator") projected = projectMercator(grid, lat, lon);
  else if (grid.kind === "polar") projected = projectPolar(grid, lat, lon);
  else throw new Error(`unsupported_grid_kind_${grid.kind}`);

  const i = Math.round(projected.i);
  const j = Math.round(projected.j);
  if (i < 0 || j < 0 || i >= grid.nx || j >= grid.ny) return null;
  return { i, j, index: j * grid.nx + i };
}

/**
 * Rough domain pick. The GRIB grid still rejects a point that does not land
 * on it. Nationwide — not locked to one city.
 */
export function domainFor(lat, lon) {
  let lo = lon;
  while (lo < -180) lo += 360;
  while (lo > 180) lo -= 360;
  if (lat >= 17 && lat <= 26 && lo <= -150 && lo >= -165) return "hi";
  if (lat >= 14.5 && lat <= 24 && lo <= -63 && lo >= -72) return "pr";
  if (lat >= 50 && (lo <= -130 || lo >= 170)) return "ak";
  if (lat >= 20 && lat <= 53 && lo <= -60 && lo >= -135) return "conus";
  return null;
}
