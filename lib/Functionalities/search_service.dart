import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single geocoding result from Nominatim / OpenStreetMap.
class LocationResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> raw;

  LocationResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.raw,
  });

  factory LocationResult.fromJson(Map<String, dynamic> j) {
    return LocationResult(
      displayName: j['display_name'] as String? ?? '',
      latitude: double.tryParse(j['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(j['lon']?.toString() ?? '') ?? 0.0,
      raw: j,
    );
  }
}

/// Search Nominatim (OpenStreetMap) for the provided query string.
///
/// Returns a list of [LocationResult] (possibly empty) or throws an [Exception]
/// on network / parsing errors.
///
/// Example:
/// final results = await searchNominatim('Utrecht, Netherlands', limit: 5);
/// Optionally limit search to specific country codes (comma separated, ISO 3166-1alpha2),
/// e.g. `countryCodes: 'nl'` to prefer Netherlands results.
Future<List<LocationResult>> searchNominatim(String query, {int limit = 5, String? countryCodes}) async {
  if (query.trim().isEmpty) return [];

  final params = <String, String>{
    'q': query,
    'format': 'json',
    'addressdetails': '1',
    'limit': limit.toString(),
  };
  if (countryCodes != null && countryCodes.trim().isNotEmpty) {
    params['countrycodes'] = countryCodes;
  }

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);

  // Nominatim usage policy requests a descriptive user agent and optional
  // contact info. Keep the user agent meaningful for server operators.
  final headers = {
    'Accept': 'application/json',
    'User-Agent': 'TruckerReview/1.0 (https://example.com)'
  };

  final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

  if (resp.statusCode != 200) {
    throw Exception('Nominatim returned ${resp.statusCode}');
  }

  final List<dynamic> jsonList = json.decode(resp.body) as List<dynamic>;
  final results = jsonList
      .map((e) => LocationResult.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
  return results;
}
