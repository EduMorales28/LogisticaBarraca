import 'package:flutter/material.dart';

Widget buildGoogleMapsPreview({
  required String address,
  double height = 280,
}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD7D7D7)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        address.trim().isEmpty
            ? 'Escribe una direccion para ver la previsualizacion del mapa.'
            : 'La previsualizacion embebida de Google Maps esta disponible en web.\nPuedes abrir el destino en Maps desde el enlace.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF66666A)),
      ),
    ),
  );
}
