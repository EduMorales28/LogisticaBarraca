import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../authz.dart';
import 'orders_page.dart';

enum DeliveredFilter { all, finalOnly, partialOnly, failedOnly }

class DeliveredFirestorePage extends StatelessWidget {
  final DeliveredFilter filter;

  const DeliveredFirestorePage({super.key, this.filter = DeliveredFilter.all});

  bool _include(Map<String, dynamic> data) {
    if (data['deleted'] == true) return false;
    final estado = (data['estado'] ?? '').toString();
    final progress = (data['deliveryProgress'] ?? '').toString();
    return switch (filter) {
      DeliveredFilter.finalOnly => estado == 'entregado' || progress == 'completo',
      DeliveredFilter.partialOnly => estado == 'entrega_parcial' || progress == 'parcial',
      DeliveredFilter.failedOnly => estado == 'entrega_fallida' || progress == 'fallido',
      DeliveredFilter.all => estado == 'entregado' || estado == 'entrega_fallida' || estado == 'entrega_parcial' || progress == 'completo' || progress == 'fallido' || progress == 'parcial',
    };
  }

  String _title() {
    return switch (filter) {
      DeliveredFilter.finalOnly => 'Entregados',
      DeliveredFilter.partialOnly => 'Entregas parciales',
      DeliveredFilter.failedOnly => 'Entregas fallidas',
      DeliveredFilter.all => 'Entregados / Cerrados',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final docs = (snapshot.data?.docs ?? []).where((doc) => _include(doc.data())).toList();
        docs.sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final at = ad['finalDeliveredAt'] ?? ad['deliveredAt'] ?? ad['lastDeliveryUpdateAt'];
          final bt = bd['finalDeliveredAt'] ?? bd['deliveredAt'] ?? bd['lastDeliveryUpdateAt'];
          if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
          if (at is Timestamp) return -1;
          if (bt is Timestamp) return 1;
          return 0;
        });

        if (docs.isEmpty) return Center(child: Text('No hay registros para ${_title().toLowerCase()}'));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_title(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data();
              final receiver = (data['deliveryReceiverName'] ?? '').toString().trim();
              final hasPhoto = (data['deliveryPhotoUrl'] ?? '').toString().trim().isNotEmpty || ((data['deliveryPhotoUrls'] as List?)?.isNotEmpty ?? false);
              final hasLocation = (data['deliveryMapLink'] ?? '').toString().trim().isNotEmpty || (data['deliveryLat'] != null && data['deliveryLng'] != null);
              final finalDate = data['finalDeliveredAt'] ?? data['deliveredAt'] ?? data['lastDeliveryUpdateAt'];
              return Card(
                child: ListTile(
                  title: Text((data['orderNumber'] ?? data['clienteNombreSnapshot'] ?? '-').toString()),
                 subtitle: Text(
  '${data['direccionTexto'] ?? ''}\n'
  'Estado: ${data['estado'] ?? ''}\n'
  'Fecha final: ${finalDate is Timestamp ? finalDate.toDate().toString() : '-'}\n'
  'Recibió: ${receiver.isEmpty ? '-' : receiver}\n'
  'Foto: ${hasPhoto ? 'sí' : 'no'} · Ubicación: ${hasLocation ? 'sí' : 'no'}',
),
                  isThreeLine: false,
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrderDetailFirestorePage(orderId: doc.id, profile: CurrentAppUserScope.of(context))),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver'),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
