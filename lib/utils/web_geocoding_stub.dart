// ignore: deprecated_member_use
import 'dart:js' as js;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// This is a web-only helper. 
/// On mobile, it will not be imported or used.
void getWebAddress(LatLng location, Function(String) onResult) {
  try {
    final geocoder = js.JsObject(js.context['google']['maps']['Geocoder']);
    final request = js.JsObject.jsify({
      'location': {'lat': location.latitude, 'lng': location.longitude}
    });

    geocoder.callMethod('geocode', [
      request,
      js.allowInterop((results, status) {
        if (status == 'OK' && results != null && results.length > 0) {
          onResult(results[0]['formatted_address']);
        } else {
          onResult("Google Error: $status");
        }
      })
    ]);
  } catch (e) {
    onResult("Bridge Error: ${e.toString()}");
  }
}
