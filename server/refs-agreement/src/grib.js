/**
 * Point extract for NCEP GRIB2 complex packing with spatial differencing
 * (templates 5.3 / 7.3). REFS eas and HRRR hourly precip use this packing.
 * Decodes only through the requested grid index — order-2 differences are
 * a running pair, not a nationwide array kept in memory.
 */

const EARTH_RADIUS_SPHERICAL_CODE6 = 6_371_229;

export function signMagnitude16(raw) {
  const sign = raw & 0x8000 ? -1 : 1;
  return sign * (raw & 0x7fff);
}

export function ieeeFloat32(buf, offset) {
  return new DataView(buf.buffer, buf.byteOffset, buf.byteLength).getFloat32(offset, false);
}

class BitReader {
  constructor(buf, bitpos) {
    this.buf = buf;
    this.bitpos = bitpos;
  }

  read(n) {
    if (n <= 0) return 0;
    let value = 0;
    let left = n;
    while (left > 0) {
      const byteIndex = this.bitpos >> 3;
      const bitInByte = this.bitpos & 7;
      const available = 8 - bitInByte;
      const take = left < available ? left : available;
      const shift = available - take;
      const mask = (1 << take) - 1;
      const byte = this.buf[byteIndex] ?? 0;
      value = value * 2 ** take + ((byte >> shift) & mask);
      this.bitpos += take;
      left -= take;
    }
    return value;
  }

  align() {
    const rem = this.bitpos & 7;
    if (rem) this.bitpos += 8 - rem;
  }
}

function sectionAt(buf, start) {
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const length = view.getUint32(start, false);
  const number = buf[start + 4];
  return { start, length, number };
}

function walkSections(buf) {
  if (buf.length < 16 || buf[0] !== 0x47 || buf[1] !== 0x52 || buf[2] !== 0x49 || buf[3] !== 0x42) {
    throw new Error("not_grib");
  }
  const sections = [];
  let offset = 16;
  while (offset + 5 <= buf.length) {
    const section = sectionAt(buf, offset);
    sections.push(section);
    if (section.number === 7) break;
    if (section.length < 5) throw new Error("bad_section");
    offset += section.length;
  }
  return sections;
}

function scaledRadius(buf, sectionStart) {
  const shape = buf[sectionStart + 14];
  if (shape === 6) return EARTH_RADIUS_SPHERICAL_CODE6;
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const scale = buf[sectionStart + 15];
  const value = view.getUint32(sectionStart + 16, false);
  const radius = value / 10 ** scale;
  return radius > 0 ? radius : EARTH_RADIUS_SPHERICAL_CODE6;
}

function microdegrees(buf, offset) {
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  return view.getInt32(offset, false) / 1e6;
}

function metersFromMilli(buf, offset) {
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  return view.getUint32(offset, false) / 1000;
}

/**
 * Grid templates the REFS domains actually ship:
 * 30 Lambert conformal (conus), 20 polar stereographic (ak), 10 mercator (hi, pr).
 */
export function readGrid(buf) {
  const gridSection = walkSections(buf).find((section) => section.number === 3);
  if (!gridSection) throw new Error("missing_grid");
  const start = gridSection.start;
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const template = view.getUint16(start + 12, false);
  const radius = scaledRadius(buf, start);
  const nx = view.getUint32(start + 30, false);
  const ny = view.getUint32(start + 34, false);
  const lat1 = microdegrees(buf, start + 38);
  const lon1 = microdegrees(buf, start + 42);
  if (template === 10) {
    return {
      kind: "mercator",
      radius,
      nx,
      ny,
      lat1,
      lon1,
      lad: microdegrees(buf, start + 47),
      dx: metersFromMilli(buf, start + 64),
      dy: metersFromMilli(buf, start + 68),
      scan: buf[start + 59],
    };
  }
  if (template === 20 || template === 30) {
    return {
      kind: template === 20 ? "polar" : "lambert",
      radius,
      nx,
      ny,
      lat1,
      lon1,
      lad: microdegrees(buf, start + 47),
      lov: microdegrees(buf, start + 51),
      dx: metersFromMilli(buf, start + 55),
      dy: metersFromMilli(buf, start + 59),
      projectionCenter: buf[start + 63],
      scan: buf[start + 64],
      latin1: template === 30 ? microdegrees(buf, start + 65) : microdegrees(buf, start + 47),
      latin2: template === 30 ? microdegrees(buf, start + 69) : microdegrees(buf, start + 47),
    };
  }
  throw new Error(`unsupported_grid_${template}`);
}

function readRepresentation(buf) {
  const section = walkSections(buf).find((item) => item.number === 5);
  if (!section) throw new Error("missing_drs");
  const start = section.start;
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const template = view.getUint16(start + 9, false);
  if (template !== 3 && template !== 2) throw new Error(`unsupported_drs_${template}`);
  const base = start + 11;
  return {
    template,
    reference: ieeeFloat32(buf, base),
    binaryScale: signMagnitude16(view.getUint16(base + 4, false)),
    decimalScale: signMagnitude16(view.getUint16(base + 6, false)),
    bitsPerGroupRef: buf[base + 8],
    missing: buf[base + 11],
    groupCount: view.getUint32(base + 20, false),
    widthReference: buf[base + 24],
    widthBits: buf[base + 25],
    lengthReference: view.getUint32(base + 26, false),
    lengthIncrement: buf[base + 30],
    lastGroupLength: view.getUint32(base + 31, false),
    lengthBits: buf[base + 35],
    spatialOrder: template === 3 ? buf[base + 36] : 0,
    extraOctets: template === 3 ? buf[base + 37] : 0,
    pointCount: view.getUint32(start + 5, false),
  };
}

/**
 * Value at one grid index. `index` is j * nx + i, scanning +i then +j.
 * Returns the scaled geophysical value (percent for REFS eas, mm for HRRR precip).
 */
export function valueAtIndex(buf, index) {
  const drs = readRepresentation(buf);
  if (drs.missing !== 0) throw new Error("missing_values_unsupported");
  if (index < 0 || index >= drs.pointCount) throw new Error("index_outside_grid");
  const data = walkSections(buf).find((section) => section.number === 7);
  if (!data) throw new Error("missing_data");

  const reader = new BitReader(buf, (data.start + 5) * 8);
  let first = 0;
  let second = 0;
  let minimum = 0;
  if (drs.template === 3 && drs.extraOctets > 0) {
    const width = drs.extraOctets * 8;
    first = reader.read(width);
    if (drs.spatialOrder === 2) second = reader.read(width);
    const sign = reader.read(1);
    minimum = reader.read(width - 1);
    if (sign === 1) minimum = -minimum;
  }

  if (drs.groupCount === 0) return drs.reference;

  const refs = new Array(drs.groupCount);
  for (let group = 0; group < drs.groupCount; group += 1) {
    refs[group] = drs.bitsPerGroupRef ? reader.read(drs.bitsPerGroupRef) : 0;
  }
  reader.align();

  const widths = new Array(drs.groupCount);
  for (let group = 0; group < drs.groupCount; group += 1) {
    const raw = drs.widthBits ? reader.read(drs.widthBits) : 0;
    widths[group] = raw + drs.widthReference;
  }
  reader.align();

  const lengths = new Array(drs.groupCount);
  for (let group = 0; group < drs.groupCount; group += 1) {
    const raw = drs.lengthBits ? reader.read(drs.lengthBits) : 0;
    lengths[group] = raw * drs.lengthIncrement + drs.lengthReference;
  }
  lengths[drs.groupCount - 1] = drs.lastGroupLength;
  reader.align();

  const binary = 2 ** drs.binaryScale;
  const decimal = 10 ** -drs.decimalScale;
  const scale = (integer) => (integer * binary + drs.reference) * decimal;

  let point = 0;
  let previous = 0;
  let current = 0;
  for (let group = 0; group < drs.groupCount; group += 1) {
    const width = widths[group];
    const reference = refs[group];
    const length = lengths[group];
    for (let k = 0; k < length; k += 1) {
      const packed = width === 0 ? reference : reader.read(width) + reference;
      let integer;
      if (drs.template === 3 && drs.spatialOrder === 2) {
        if (point === 0) integer = first;
        else if (point === 1) integer = second;
        else integer = packed + minimum + 2 * current - previous;
      } else if (drs.template === 3 && drs.spatialOrder === 1) {
        if (point === 0) integer = first;
        else integer = packed + minimum + current;
      } else {
        integer = packed;
      }
      if (point === index) return scale(integer);
      previous = current;
      current = integer;
      point += 1;
    }
  }
  throw new Error("point_not_reached");
}
