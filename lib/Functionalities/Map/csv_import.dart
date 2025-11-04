import 'package:file_selector/file_selector.dart';

/// Opens a file picker for CSV files and returns up to [maxAddresses]
/// addresses parsed from the first field of each non-empty line.
///
/// - Returns an empty list if the user cancels the picker.
/// - Supports basic quoted CSV fields (e.g., "\"Some, Address\"").
Future<List<String>> pickCsvAddresses({int maxAddresses = 5}) async {
  final typeGroup = const XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    mimeTypes: ['text/csv', 'application/csv'],
  );

  final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return [];

  final content = await file.readAsString();
  final lines = content.split(RegExp(r'[\r]?\n'));
  final addresses = <String>[];

  for (final raw in lines) {
    if (raw.trim().isEmpty) continue;
    final addr = parseCsvFirstField(raw);
    if (addr.isNotEmpty) addresses.add(addr);
    if (addresses.length >= maxAddresses) break;
  }

  return addresses;
}

/// Extracts the first CSV field from a single line.
///
/// Handles simple quoted fields and escaped quotes (\").
String parseCsvFirstField(String line) {
  String s = line.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('"')) {
    final match = RegExp(r'^\"((?:[^\"\\]|\\.)*)\"').firstMatch(s);
    if (match != null) {
      final val = match.group(1) ?? '';
      return val.replaceAll('\\"', '"').trim();
    }
  }
  // Fallback: take up to first comma
  return s.split(',').first.trim();
}
