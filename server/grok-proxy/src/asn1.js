/**
 * Minimal DER reader — only the subset X.509 certificate parsing needs.
 *
 * Deliberately dependency-free so the same code runs on Cloudflare Workers and
 * under `node:test`. This is not a general ASN.1 library: it handles definite
 * lengths and single-byte tags, which is all DER certificates use.
 */

export const TAG = {
  INTEGER: 0x02,
  BIT_STRING: 0x03,
  OCTET_STRING: 0x04,
  OID: 0x06,
  UTF8_STRING: 0x0c,
  SEQUENCE: 0x30,
  SET: 0x31,
  UTC_TIME: 0x17,
  GENERALIZED_TIME: 0x18,
};

/** Reads one tag-length-value triple starting at `offset`. */
export function readTLV(bytes, offset = 0) {
  if (offset + 2 > bytes.length) throw new Error("DER: truncated header");

  const tag = bytes[offset];
  if ((tag & 0x1f) === 0x1f) throw new Error("DER: multi-byte tags unsupported");

  let cursor = offset + 1;
  let length = bytes[cursor++];

  if (length & 0x80) {
    const byteCount = length & 0x7f;
    // 0 is the indefinite form (not legal in DER); >4 exceeds anything we parse.
    if (byteCount === 0 || byteCount > 4) throw new Error("DER: unsupported length form");
    if (cursor + byteCount > bytes.length) throw new Error("DER: truncated length");
    length = 0;
    for (let i = 0; i < byteCount; i++) length = length * 256 + bytes[cursor++];
  }

  const end = cursor + length;
  if (end > bytes.length) throw new Error("DER: truncated value");

  return {
    tag,
    length,
    contents: bytes.subarray(cursor, end),
    /** The whole triple including its header — what you re-sign or re-import. */
    full: bytes.subarray(offset, end),
    end,
  };
}

/** Reads every direct child of a constructed TLV. */
export function readChildren(tlv) {
  const out = [];
  let offset = 0;
  while (offset < tlv.contents.length) {
    const child = readTLV(tlv.contents, offset);
    out.push(child);
    offset = child.end;
  }
  return out;
}

/** Decodes an OID's contents to dotted-decimal form. */
export function decodeOID(contents) {
  if (contents.length === 0) throw new Error("DER: empty OID");

  const parts = [Math.floor(contents[0] / 40), contents[0] % 40];
  let value = 0;

  for (let i = 1; i < contents.length; i++) {
    const byte = contents[i];
    value = value * 128 + (byte & 0x7f);
    if ((byte & 0x80) === 0) {
      parts.push(value);
      value = 0;
    }
  }

  if (value !== 0) throw new Error("DER: truncated OID");
  return parts.join(".");
}

/**
 * Decodes UTCTime / GeneralizedTime to epoch milliseconds.
 * UTCTime's two-digit year follows RFC 5280: 50-99 => 19xx, 00-49 => 20xx.
 */
export function decodeTime(tlv) {
  const text = new TextDecoder().decode(tlv.contents);

  let match;
  if (tlv.tag === TAG.UTC_TIME) {
    match = /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text);
    if (!match) throw new Error("DER: malformed UTCTime");
    const twoDigitYear = Number(match[1]);
    match[1] = String(twoDigitYear >= 50 ? 1900 + twoDigitYear : 2000 + twoDigitYear);
  } else if (tlv.tag === TAG.GENERALIZED_TIME) {
    match = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text);
    if (!match) throw new Error("DER: malformed GeneralizedTime");
  } else {
    throw new Error(`DER: unexpected time tag 0x${tlv.tag.toString(16)}`);
  }

  return Date.UTC(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    Number(match[4]),
    Number(match[5]),
    Number(match[6])
  );
}

/** Strips the unused-bits prefix byte from a BIT STRING. */
export function bitStringBytes(tlv) {
  if (tlv.tag !== TAG.BIT_STRING) throw new Error("DER: expected BIT STRING");
  if (tlv.contents.length === 0) throw new Error("DER: empty BIT STRING");
  if (tlv.contents[0] !== 0) throw new Error("DER: unaligned BIT STRING");
  return tlv.contents.subarray(1);
}
