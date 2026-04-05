import 'package:flutter/widgets.dart';

import 'google_maps_preview_stub.dart'
    if (dart.library.html) 'google_maps_preview_web.dart' as preview;

Widget buildGoogleMapsPreview({
  required String address,
  double height = 280,
}) {
  return preview.buildGoogleMapsPreview(address: address, height: height);
}
