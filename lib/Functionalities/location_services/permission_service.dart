import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);
  @override
  String toString() => 'PermissionException: $message';
}

/// Ensure location services are enabled and the app has appropriate
/// location permissions. Throws [PermissionException] when checks fail.
Future<void> ensureLocationPermission() async {
  if (kIsWeb) return; // browser handles permissions itself

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw PermissionException('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw PermissionException('Location permissions are denied.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw PermissionException('Location permissions are permanently denied.');
  }
}
