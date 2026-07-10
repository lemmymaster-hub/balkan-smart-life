import '../services/bsl_location_service.dart';

class BslStartupResult {
  final BslLocationResult? location;
  final Object? locationError;

  const BslStartupResult({
    required this.location,
    required this.locationError,
  });

  bool get hasLocation => location != null;
}

class BslStartupService {
  final BslLocationService _locationService;

  BslStartupService({
    BslLocationService? locationService,
  }) : _locationService = locationService ?? BslLocationService();

  Future<BslStartupResult> initialize() async {
    BslLocationResult? location;
    Object? locationError;

    try {
      location = await _locationService.getCurrentLocation();
    } catch (error) {
      locationError = error;
    }

    return BslStartupResult(
      location: location,
      locationError: locationError,
    );
  }
}