import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef _ZipEntry = ({int method, int size, int compressed, int offset});

/// Reads only the score and the manifest, without extracting paths to disk.
Uint8List unpackMusicXml(Uint8List bytes) {
  const maxSize = 50 << 20;
  const invalid = FormatException('Invalid compressed MusicXML.');
  final data = ByteData.sublistView(bytes);
  int word(int offset) => data.getUint16(offset, Endian.little);
  int dword(int offset) => data.getUint32(offset, Endian.little);

  var end = bytes.length - 22;
  final first = end - 65535;
  while (end >= 0 &&
      end >= first &&
      (dword(end) != 0x06054b50 || end + 22 + word(end + 20) != bytes.length)) {
    end--;
  }
  if (end < 0 || end < first) throw invalid;
  final count = word(end + 10);
  var offset = dword(end + 16);
  final entries = <String, _ZipEntry>{};
  if (count > 100) throw invalid;
  for (var i = 0; i < count; i++) {
    if (offset + 46 > end ||
        dword(offset) != 0x02014b50 ||
        (word(offset + 8) & 1) != 0) {
      throw invalid;
    }
    final nameEnd = offset + 46 + word(offset + 28);
    final next = nameEnd + word(offset + 30) + word(offset + 32);
    if (next > end) throw invalid;
    final name = utf8.decode(
      bytes.sublist(offset + 46, nameEnd),
      allowMalformed: true,
    );
    entries.putIfAbsent(
      name,
      () => (
        method: word(offset + 10),
        size: dword(offset + 24),
        compressed: dword(offset + 20),
        offset: dword(offset + 42),
      ),
    );
    offset = next;
  }

  var remaining = maxSize;
  Uint8List read(_ZipEntry entry) {
    final local = entry.offset;
    if (entry.size > remaining ||
        local + 30 > end ||
        dword(local) != 0x04034b50) {
      throw invalid;
    }
    final start = local + 30 + word(local + 26) + word(local + 28);
    final finish = start + entry.compressed;
    if (finish > end) throw invalid;
    final compressed = Uint8List.sublistView(bytes, start, finish);
    final result = switch (entry.method) {
      0 => compressed,
      8 => _inflate(compressed, entry.size),
      _ => throw invalid,
    };
    if (result.length != entry.size) throw invalid;
    remaining -= result.length;
    return result;
  }

  final manifest = entries['META-INF/container.xml'];
  final root = manifest == null
      ? null
      : RegExp(r'''<rootfile\b[^>]*\bfull-path\s*=\s*(["'])(.*?)\1''')
            .firstMatch(utf8.decode(read(manifest), allowMalformed: true))
            ?.group(2)
            ?.replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
  final score =
      entries[root] ??
      entries.entries
          .where((entry) {
            final name = entry.key.toLowerCase();
            return !name.startsWith('meta-inf/') &&
                (name.endsWith('.xml') || name.endsWith('.musicxml'));
          })
          .firstOrNull
          ?.value;
  if (score == null) throw invalid;
  return read(score);
}

Uint8List _inflate(Uint8List bytes, int limit) {
  final sink = _BoundedBytes(limit);
  final decoder = ZLibDecoder(raw: true).startChunkedConversion(sink);
  decoder.add(bytes);
  decoder.close();
  return sink.bytes.takeBytes();
}

class _BoundedBytes implements Sink<List<int>> {
  final int limit;
  final bytes = BytesBuilder(copy: false);
  _BoundedBytes(this.limit);

  @override
  void add(List<int> data) {
    if (bytes.length + data.length > limit) {
      throw const FormatException('Decompressed MusicXML is too large.');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
