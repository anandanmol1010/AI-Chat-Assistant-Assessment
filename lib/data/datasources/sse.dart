import 'dart:convert';

Stream<String> sseData(Stream<List<int>> bytes) async* {
  final lines = utf8.decoder.bind(bytes).transform(const LineSplitter());
  final data = <String>[];
  await for (final line in lines.timeout(const Duration(seconds: 45))) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield data.join('\n');
      data.clear();
    } else if (line == 'data' || line.startsWith('data:')) {
      final value = line.length > 4 ? line.substring(5) : '';
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
}
