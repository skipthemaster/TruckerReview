import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Home page which shows a movable Google Map centered on Utrecht, NL.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GoogleMapController _mapController;
  final Completer<GoogleMapController> _controllerCompleter = Completer();

  static const LatLng _utrecht = LatLng(52.0907, 5.1214);
  static const CameraPosition _initialCamera = CameraPosition(
    target: _utrecht,
    zoom: 13.0,
  );

  final Set<Marker> _markers = {
    Marker(markerId: MarkerId('utrecht'), position: _utrecht, infoWindow: InfoWindow(title: 'Utrecht')),
  };

  @override
  void dispose() {
    // tidy up map controller when the widget is removed
    _mapController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _controllerCompleter.complete(controller);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapHeight = MediaQuery.of(context).size.height * 0.5; // half the screen

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

            // Map container
            SizedBox(
              height: mapHeight,
              width: double.infinity,
              child: Card(
                clipBehavior: Clip.hardEdge,
                child: GoogleMap(
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: _initialCamera,
                  markers: _markers,
                  mapType: MapType.normal,
                ),
              ),
            ),

            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Center on Utrecht'),
                onTap: () async {
                  final controller = await _controllerCompleter.future;
                  controller.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
                },
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
