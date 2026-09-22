import 'dart:async';
import 'package:cooking_daddy/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _LocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission answer = LocationPermission.whileInUse;
  bool enabled = true;
  bool timeout = false;
  int prompts = 0;
  int positionRequests = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return answer;
  }
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    positionRequests++;
    expect(locationSettings!.accuracy, LocationAccuracy.low);
    expect(locationSettings.timeLimit, const Duration(seconds: 10));
    if (timeout) throw TimeoutException('No GPS fix');
    return Position(latitude: 10.77691, longitude: 106.70094,
      timestamp: DateTime(2026), accuracy: 1000, altitude: 0, altitudeAccuracy: 0,
      heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
  }
}

void main() {
  test('requests permission and returns city-level coordinates', () async {
    final platform = _LocationPlatform();
    final result = await LocationService(platform: platform).requestLocation();
    expect(platform.prompts, 1);
    expect(platform.positionRequests, 1);
    expect(result!.toJson(), {'latitude': 10.78, 'longitude': 106.7});
  });

  test('denial never reads location', () async {
    final platform = _LocationPlatform()..answer = LocationPermission.denied;
    expect(await LocationService(platform: platform).requestLocation(), isNull);
    expect(platform.prompts, 1);
    expect(platform.positionRequests, 0);
  });

  test('permanent denial does not repeatedly prompt', () async {
    final platform = _LocationPlatform()..permission = LocationPermission.deniedForever;
    expect(await LocationService(platform: platform).requestLocation(), isNull);
    expect(platform.prompts, 0);
    expect(platform.positionRequests, 0);
  });

  test('existing permission does not prompt again', () async {
    final platform = _LocationPlatform()..permission = LocationPermission.whileInUse;
    expect(await LocationService(platform: platform).requestLocation(), isNotNull);
    expect(platform.prompts, 0);
  });

  test('disabled location services and timeout fall back without location', () async {
    final platform = _LocationPlatform()..enabled = false;
    final service = LocationService(platform: platform);
    expect(await service.requestLocation(), isNull);
    expect(platform.positionRequests, 0);
    platform.enabled = true;
    platform.timeout = true;
    expect(await service.requestLocation(), isNull);
  });
}
