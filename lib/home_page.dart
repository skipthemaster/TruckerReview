import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'Functionalities/location_services/location_service.dart';
import 'Functionalities/search_service.dart';
import 'Functionalities/Map/csv_import.dart';

/// Home page showing an OpenStreetMap map (flutter_map) centered on Utrecht, NL.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();

  static final LatLng _utrecht = LatLng(52.0907, 5.1214);
  double _zoom = 8.0;
  LatLng _center = _utrecht;
  Position? _currentPosition;
  bool _locating = false;
  double? _currentAccuracy;
  // Map zoom bounds
  final double _minZoom = 6.0;
  final double _maxZoom = 18.0;
  // Persistent user-added markers
  final List<Marker> _userMarkers = [];
  // UI state for add-location inputs
  bool _showAddInputs = false;
  late final TextEditingController _addTitleController;
  late final TextEditingController _addNoteController;
  // Extra dynamic fields (max total fields = 5 including title & note)
  final List<TextEditingController> _extraControllers = [];
  // Simple search input controller (above map)
  late final TextEditingController _searchController;
  bool _searching = false;
  Marker? _searchResultMarker;
  // Autocomplete removed

  @override
  void initState() {
    super.initState();
    _addTitleController = TextEditingController();
    _addNoteController = TextEditingController();
    _searchController = TextEditingController();
    // Start location lookup right after the first frame so UI is available for
    // permission prompts and snackbars.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePositionAndMove();
    });
  }

  @override
  void dispose() {
    _addTitleController.dispose();
    _addNoteController.dispose();
    _searchController.dispose();
    for (final c in _extraControllers) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapHeight = MediaQuery.of(context).size.height * 0.5;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text('Welcome to Trucker Review', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Interactive map (movable) centered on Utrecht, Netherlands.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Simple search input above the map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  // Add a clickable suffix button to run the search.
                  suffixIcon: _searching
                      ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0)))
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () async {
                            final q = _searchController.text.trim();
                            if (q.isEmpty) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a search query')));
                              return;
                            }
                            await _performSearch(q);
                          },
                        ),
                ),
                onSubmitted: (value) {
                  final q = value.trim();
                  if (q.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a search query')));
                    return;
                  }
                  _performSearch(q);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Map container
            SizedBox(
              height: mapHeight,
              width: double.infinity,
              child: Card(
                clipBehavior: Clip.hardEdge,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _center,
                    zoom: _zoom,
                    // Prevent requesting tiles at zoom levels higher than the provider.
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    onPositionChanged: (pos, _) {
                      // pos.zoom and pos.center can be nullable; apply sensible fallbacks
                      final z = (pos.zoom ?? _zoom).clamp(_minZoom, _maxZoom);
                      final c = pos.center ?? _center;
                      setState(() {
                        _zoom = z;
                        _center = c;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.trucker_review_app',
                      // Tell the tile layer the highest native zoom the tile server provides.
                      // This helps when using fractional zoom values so flutter_map will rescale
                      // tiles instead of requesting non-existent higher-zoom tiles.
                      maxNativeZoom: 18,
                    ),
                    // Marker for the last search result (green)
                    if (_searchResultMarker != null)
                      MarkerLayer(markers: [_searchResultMarker!]),
                    // User-added markers (green) — show when present.
                    if (_userMarkers.isNotEmpty)
                      MarkerLayer(markers: _userMarkers),
                    // Show a marker only when we have the device location.
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            builder: (ctx) => const Icon(Icons.my_location, size: 32, color: Colors.blue),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('My location'),
                  onPressed: _locating
                      ? null
                      : () async {
                          await _determinePositionAndMove();
                        },
                ),
                const SizedBox(width: 8),
                // Add location button: show two input fields when clicked.
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_location),
                  label: const Text('Add multiple addresses'),
                  onPressed: () {
                    setState(() => _showAddInputs = true);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                  onPressed: () async {
                    await _importCsvAddresses();
                  },
                ),
                const SizedBox(width: 12),
                if (_locating) ...[
                  const SizedBox(width: 8),
                  SizedBox(width: 18, height: 18, child: const CircularProgressIndicator(strokeWidth: 2.0)),
                  const SizedBox(width: 8),
                  Text(
                    _currentAccuracy == null
                        ? 'Searching...'
                        : 'Accuracy: ${_currentAccuracy!.toStringAsFixed(1)} m',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else ...[
                  if (_currentPosition != null)
                    Text(
                      'Location: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Text('Zoom: ${_zoom.toStringAsFixed(1)}', style: theme.textTheme.bodyMedium),
                ]
              ],
            ),
            // Add-location input area
            if (_showAddInputs) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _addTitleController,
                      decoration: const InputDecoration(labelText: 'A', hintText: 'Type in address'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addNoteController,
                      decoration: const InputDecoration(labelText: 'B', hintText: 'Type in address'),
                    ),
                    const SizedBox(height: 8),
                    // Extra dynamic fields
                    for (var i = 0; i < _extraControllers.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _extraControllers[i],
                              decoration: InputDecoration(
                                labelText: String.fromCharCode('C'.codeUnitAt(0) + i),
                                hintText: 'Type in address',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove field',
                            onPressed: () {
                              setState(() {
                                _extraControllers[i].dispose();
                                _extraControllers.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Add-field button (adds up to 5 total fields)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          const int base = 2; // title + note
                          const int maxTotal = 5;
                          final remaining = maxTotal - base - _extraControllers.length;
                          if (remaining <= 0) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum of 5 fields reached')));
                            return;
                          }

                          setState(() {
                            _extraControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add field'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Cancel: hide inputs, clear base and extra fields
                            setState(() {
                              _showAddInputs = false;
                              _addTitleController.clear();
                              _addNoteController.clear();
                              for (final c in _extraControllers) {
                                c.dispose();
                              }
                              _extraControllers.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            // Geocode addresses from fields A, B, C... and place markers on the map
                            // with the corresponding letter shown on each marker.
                            final inputs = <MapEntry<String, String>>[];
                            final a = _addTitleController.text.trim();
                            final b = _addNoteController.text.trim();
                            if (a.isNotEmpty) inputs.add(MapEntry('A', a));
                            if (b.isNotEmpty) inputs.add(MapEntry('B', b));
                            for (var i = 0; i < _extraControllers.length; i++) {
                              final t = _extraControllers[i].text.trim();
                              if (t.isNotEmpty) {
                                final letter = String.fromCharCode('C'.codeUnitAt(0) + i);
                                inputs.add(MapEntry(letter, t));
                              }
                            }

                            if (inputs.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least one address.')));
                              }
                              return;
                            }

                            // Start a fresh route: clear previous markers and last search marker
                            setState(() {
                              _userMarkers.clear();
                              _searchResultMarker = null;
                            });

                            int added = 0;
                            int notFound = 0;
                            int errors = 0;
                            LatLng? firstPoint;

                            for (final entry in inputs) {
                              try {
                                final results = await searchNominatim(entry.value, limit: 1, countryCodes: 'nl');
                                if (results.isEmpty) {
                                  notFound += 1;
                                  continue;
                                }
                                final r = results.first;
                                final pt = LatLng(r.latitude, r.longitude);
                                firstPoint ??= pt;
                                setState(() {
                                  _userMarkers.add(
                                    Marker(
                                      width: 40,
                                      height: 40,
                                      point: pt,
                                      builder: (ctx) => Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Icon(Icons.place, size: 32, color: Colors.green),
                                          // Letter overlay (A, B, C, ...)
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              shadows: [
                                                Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(0, 0)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                });
                                added += 1;
                              } catch (_) {
                                errors += 1;
                              }
                            }

                            // Zoom to show all markers
                            _fitToAllMarkers();

                            // Keep the input fields open with current text intact (no clearing)

                            if (mounted) {
                              final parts = <String>[];
                              if (added > 0) parts.add('Added $added');
                              if (notFound > 0) parts.add('Not found $notFound');
                              if (errors > 0) parts.add('Errors $errors');
                              final msg = parts.isEmpty ? 'No markers added' : parts.join(', ');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _determinePositionAndMove() async {
    // Delegate orchestration to LocationService but keep UI updates here via callbacks.
    setState(() {
      _locating = true;
      _currentAccuracy = null;
    });

    await LocationService.locateWithCallbacks(
      onStart: () {},
      onAccuracy: (a) {
        if (mounted) setState(() => _currentAccuracy = a);
      },
      onSuccess: (pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _currentAccuracy = pos.accuracy;
            // Zoom closer when centering to the device location.
            _zoom = 18.0;
          });
          _mapController.move(LatLng(pos.latitude, pos.longitude), _zoom);
        }
      },
      onError: (msg) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      onComplete: () {
        if (mounted) setState(() => _locating = false);
      },
      requiredAccuracyMeters: 10.0,
      timeout: const Duration(seconds: 12),
    );

  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
  final results = await searchNominatim(query, limit: 1, countryCodes: 'nl');
      if (results.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found')));
        return;
      }

      final r = results.first;
      final lat = r.latitude;
      final lon = r.longitude;

      final marker = Marker(
        width: 40,
        height: 40,
        point: LatLng(lat, lon),
        builder: (ctx) => const Icon(Icons.place, size: 32, color: Colors.green),
      );

      setState(() {
        _searchResultMarker = marker;
        _zoom = 16.0;
      });

      // Move the map to the found location.
      _mapController.move(LatLng(lat, lon), _zoom);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Found: ${r.displayName}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _fitToAllMarkers() async {
    // Collect all marker points shown on the map
    final points = <LatLng>[];
    for (final m in _userMarkers) {
      points.add(m.point);
    }
    if (_searchResultMarker != null) {
      points.add(_searchResultMarker!.point);
    }

    if (points.isEmpty) return;

    // Single point: animate zoom from current level, pan to that point
    if (points.length == 1) {
      final targetCenter = points.first;
      final steps = 8;
      final targetZoom = 16.0.clamp(_minZoom, _maxZoom);
      final dz = (targetZoom - _zoom) / steps;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(const Duration(milliseconds: 60));
        final z = (_zoom + dz * i).clamp(_minZoom, _maxZoom).toDouble();
        // Interpolate center a bit to make it feel smoother
        final t = i / steps;
        final c = LatLng(
          _center.latitude + (targetCenter.latitude - _center.latitude) * t,
          _center.longitude + (targetCenter.longitude - _center.longitude) * t,
        );
        _mapController.move(c, z);
        if (mounted) setState(() {
          _zoom = z;
          _center = c;
        });
      }
      return;
    }

    // Multiple points: compute bounds and animate from current zoom/center towards the fit result
    final bounds = LatLngBounds.fromPoints(points);
    final boundsCenter = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );

    // Snapshot current camera
    final oldCenter = _center;
    final oldZoom = _zoom;

    // Probe target zoom by temporarily fitting the bounds
    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
    );
    // Allow onPositionChanged to update _zoom
    await Future.delayed(const Duration(milliseconds: 20));
    final targetZoom = _zoom.clamp(_minZoom, _maxZoom).toDouble();

    // Restore old camera immediately
    _mapController.move(oldCenter, oldZoom);
    if (mounted) setState(() {
      _center = oldCenter;
      _zoom = oldZoom;
    });

    // Animate center and zoom from current camera to target
    const int steps = 10;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final z = (oldZoom + (targetZoom - oldZoom) * t).clamp(_minZoom, _maxZoom).toDouble();
      final c = LatLng(
        oldCenter.latitude + (boundsCenter.latitude - oldCenter.latitude) * t,
        oldCenter.longitude + (boundsCenter.longitude - oldCenter.longitude) * t,
      );
      _mapController.move(c, z);
      if (mounted) setState(() {
        _zoom = z;
        _center = c;
      });
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }

  Future<void> _importCsvAddresses() async {
    try {
      final addresses = await pickCsvAddresses(maxAddresses: 5);
      if (addresses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No addresses found in CSV')));
        }
        return;
      }

      // Ensure input area is visible
      setState(() => _showAddInputs = true);

      // Fill A, B, then C.. up to 5 total
      void setTextSafely(TextEditingController ctrl, String text) {
        ctrl
          ..text = text
          ..selection = TextSelection.fromPosition(TextPosition(offset: text.length));
      }

      if (addresses.isNotEmpty) setTextSafely(_addTitleController, addresses[0]);
      if (addresses.length >= 2) setTextSafely(_addNoteController, addresses[1]);

      // Prepare extra controllers as needed
      final extrasNeeded = (addresses.length - 2).clamp(0, 3); // max total 5
      while (_extraControllers.length < extrasNeeded) {
        _extraControllers.add(TextEditingController());
      }
      for (int i = 0; i < extrasNeeded; i++) {
        setTextSafely(_extraControllers[i], addresses[2 + i]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}
