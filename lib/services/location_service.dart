import 'package:geolocator/geolocator.dart';

class RecipeLocation {
  final double latitude;
  final double longitude;

  const RecipeLocation({required this.latitude, required this.longitude});

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

class LocationService {
  final GeolocatorPlatform _platform;

  LocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  Future<RecipeLocation?> requestLocation() async {
    try {
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always)
        return null;
      if (!await _platform.isLocationServiceEnabled()) return null;
      final position = await _platform.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // City-level weather does not need precise coordinates.
      return RecipeLocation(
        latitude: double.parse(position.latitude.toStringAsFixed(2)),
        longitude: double.parse(position.longitude.toStringAsFixed(2)),
      );
    } catch (_) {
      return null;
    }
  }
}
