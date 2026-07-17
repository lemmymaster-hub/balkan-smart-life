import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

abstract final class BslNavigationVehicleAsset {
  static const String path = 'assets/markers/bsl_navigation_car_marker.png';
  static const double markerWidth = 32;
  static const double markerHeight = 68;

  static Future<ImageDescriptor> register(BuildContext context) async {
    final imageConfiguration = createLocalImageConfiguration(context);
    final imageKey = await const AssetImage(path).obtainKey(imageConfiguration);
    final assetData = await imageKey.bundle.load(imageKey.name);

    return registerBitmapImage(
      bitmap: assetData,
      imagePixelRatio: imageKey.scale,
      width: markerWidth,
      height: markerHeight,
    );
  }
}
