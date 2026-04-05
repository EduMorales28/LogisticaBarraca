// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final Set<String> _registeredMapViewTypes = <String>{};

Widget buildGoogleMapsPreview({
  required String address,
  double height = 280,
}) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7D7D7)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Escribe una direccion para ver la previsualizacion del mapa.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF66666A)),
        ),
      ),
    );
  }

  final encoded = Uri.encodeComponent(trimmed);
  final viewType = 'google-maps-preview-$encoded';
  if (_registeredMapViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.google.com/maps?q=$encoded&output=embed'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..referrerPolicy = 'no-referrer-when-downgrade';
      return iframe;
    });
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: height,
      child: HtmlElementView(viewType: viewType),
    ),
  );
}
