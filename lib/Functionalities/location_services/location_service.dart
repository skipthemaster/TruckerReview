import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'permission_service.dart';

class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);
  @override
  String toString() => 'LocationServiceException: $message';
}

/// A small location helper that attempts to obtain a high-accuracy fix by
/// subscribing to the device position stream until either a fix with
/// [requiredAccuracyMeters] is found or [timeout] is reached.
class LocationService {
  /// Returns a [Position] that meets the requested accuracy, or the best
  /// position seen within [timeout]. May throw [LocationServiceException]
  /// when services or permissions are unavailable.
  static Future<Position?> getAccuratePosition({
    double requiredAccuracyMeters = 10.0,
    Duration timeout = const Duration(seconds: 12),
    void Function(double?)? onAccuracy,
  }) async {
    // Ensure permissions via the PermissionService; it will throw a
    // PermissionException when checks fail. On web this is a no-op.
    await ensureLocationPermission();

    Position? best;
    final completer = Completer<Position?>();
    final accuracySetting = kIsWeb ? LocationAccuracy.high : LocationAccuracy.bestForNavigation;
    late StreamSubscription<Position> sub;

    sub = Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: accuracySetting, distanceFilter: 0)).listen(
      (pos) {
        // Report live accuracy if requested by caller.
        try {
          onAccuracy?.call(pos.accuracy);
        } catch (_) {}

        if (best == null || pos.accuracy < (best?.accuracy ?? double.infinity)) {
          best = pos;
        }

        if (pos.accuracy <= requiredAccuracyMeters) {
          if (!completer.isCompleted) completer.complete(pos);
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    Position? chosen;
    try {
      chosen = await completer.future.timeout(timeout, onTimeout: () => best);
    } finally {
      await sub.cancel();
    }

    return chosen;
  }

  /// High-level helper that orchestrates permission checks and a high-accuracy
  /// position search, invoking UI callbacks for lifecycle events. This keeps
  /// platform logic in the service layer while UI updates remain in the
  /// caller-provided callbacks.
  static Future<void> locateWithCallbacks({
    required void Function()? onStart,
    required void Function(double?) onAccuracy,
    required void Function(Position) onSuccess,
    required void Function(String) onError,
    void Function()? onComplete,
    double requiredAccuracyMeters = 10.0,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    onStart?.call();

    try {
      // Ensure permissions (will throw PermissionException on failure)
      await ensureLocationPermission();

      Position? best;
      final completer = Completer<Position?>();
      final accuracySetting = kIsWeb ? LocationAccuracy.high : LocationAccuracy.bestForNavigation;
      late StreamSubscription<Position> sub;

      sub = Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: accuracySetting, distanceFilter: 0)).listen(
        (pos) {
          // report progress
          try {
            onAccuracy(pos.accuracy);
          } catch (_) {}

          if (best == null || pos.accuracy < (best?.accuracy ?? double.infinity)) {
            best = pos;
          }

          if (pos.accuracy <= requiredAccuracyMeters) {
            if (!completer.isCompleted) completer.complete(pos);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      Position? chosen;
      try {
        chosen = await completer.future.timeout(timeout, onTimeout: () => best);
      } finally {
        await sub.cancel();
      }

      if (chosen != null) {
        onSuccess(chosen);
      } else {
        onError('Could not determine a location.');
      }
    } on PermissionException catch (e) {
      onError(e.message);
    } catch (e) {
      onError(e.toString());
    } finally {
      try {
        onComplete?.call();
      } catch (_) {}
    }
  }
}
