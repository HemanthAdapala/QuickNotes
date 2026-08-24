import 'dart:typed_data';

/// ZipArchiveEntry — Represents a single file entry inside a ZIP/QNB container.
class ZipArchiveEntry {
  final String name;
  final int compressionMethod; // 0 = Store, 8 = Deflate
  final int compressedSize;
  final int uncompressedSize;
  final int crc32;
  final List<int> data;

  ZipArchiveEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.crc32,
    required this.data,
  });
}

/// ZipDecoder — Pure-Dart ZIP container parser and inspector.
/// Parses ZIP Local File Headers and Central Directory headers safely with 0 third-party packages.
class ZipDecoder {
  ZipDecoder._();

  /// Unpacks an in-memory ZIP / QNB byte array into a map of filename -> entry data.
  /// Supports uncompressed STORE (method 0) and handles DEFLATE (method 8) raw streams if available.
  static List<ZipArchiveEntry> decode(List<int> bytes) {
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    final entries = <ZipArchiveEntry>[];
    var offset = 0;

    while (offset + 30 <= bytes.length) {
      final sig = byteData.getUint32(offset, Endian.little);
      if (sig == 0x04034b50) {
        // Local File Header
        final compMethod = byteData.getUint16(offset + 8, Endian.little);
        final compSize = byteData.getUint32(offset + 18, Endian.little);
        final uncompSize = byteData.getUint32(offset + 22, Endian.little);
        final nameLen = byteData.getUint16(offset + 26, Endian.little);
        final extraLen = byteData.getUint16(offset + 28, Endian.little);

        final nameOffset = offset + 30;
        final dataOffset = nameOffset + nameLen + extraLen;

        if (dataOffset + compSize > bytes.length) {
          throw FormatException(
              'Zip header declares data beyond byte length at offset $offset');
        }

        final nameBytes = bytes.sublist(nameOffset, nameOffset + nameLen);
        final name = String.fromCharCodes(nameBytes);
        final rawData = bytes.sublist(dataOffset, dataOffset + compSize);

        entries.add(ZipArchiveEntry(
          name: name,
          compressionMethod: compMethod,
          compressedSize: compSize,
          uncompressedSize: uncompSize,
          crc32: byteData.getUint32(offset + 14, Endian.little),
          data: rawData,
        ));

        offset = dataOffset + compSize;
      } else if (sig == 0x02014b50 || sig == 0x06054b50) {
        // Central Directory or End of Central Directory Signature reached
        break;
      } else {
        offset++;
      }
    }

    return entries;
  }
}
