import Foundation

/// System `libbz2` (not an SPM package). N0B symbology on AWS is bzip2.
enum Level3BZip2 {
  static func decompress(_ source: Data, uncompressedSize: Int) -> Data? {
    let sizes = uncompressedSize > 0
      ? [uncompressedSize, uncompressedSize * 2, max(uncompressedSize, 2_000_000)]
      : [2_000_000, 8_000_000]
    var seen = Set<Int>()
    for size in sizes where seen.insert(size).inserted {
      if let out = decompress(source, destinationCount: size) { return out }
    }
    return nil
  }

  private static func decompress(_ source: Data, destinationCount: Int) -> Data? {
    guard destinationCount > 0, !source.isEmpty else { return nil }
    var dest = Data(count: destinationCount)
    var destLen = UInt32(destinationCount)
    var src = source
    let rc = dest.withUnsafeMutableBytes { destRaw -> Int32 in
      src.withUnsafeMutableBytes { srcRaw -> Int32 in
        guard let destPtr = destRaw.baseAddress?.assumingMemoryBound(to: Int8.self),
          let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: Int8.self)
        else { return -1 }
        return BZ2_bzBuffToBuffDecompress(
          destPtr, &destLen, srcPtr, UInt32(source.count), 0, 0)
      }
    }
    guard rc == 0 else { return nil }
    dest.count = Int(destLen)
    return dest
  }
}

@_silgen_name("BZ2_bzBuffToBuffDecompress")
func BZ2_bzBuffToBuffDecompress(
  _ dest: UnsafeMutablePointer<Int8>?,
  _ destLen: UnsafeMutablePointer<UInt32>?,
  _ source: UnsafeMutablePointer<Int8>?,
  _ sourceLen: UInt32,
  _ small: Int32,
  _ verbosity: Int32
) -> Int32
