import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../authz.dart';
import '../local_mode.dart';
import '../services/logistics_day_service.dart';
import 'package:url_launcher/url_launcher.dart';

Color _statusColor(String estado, String deliveryProgress) {
  if (estado == 'entregado' || deliveryProgress == 'completo') return Colors.green;
  if (estado == 'entrega_fallida' || deliveryProgress == 'fallido') return Colors.red;
  if (deliveryProgress == 'parcial' || estado == 'entrega_parcial') return Colors.orange;
  return Colors.amber;
}

String _statusLabel(String estado, String deliveryProgress) {
  if (estado == 'entregado' || deliveryProgress == 'completo') return 'Entregado';
  if (estado == 'entrega_fallida' || deliveryProgress == 'fallido') return 'Fallido';
  if (deliveryProgress == 'parcial' || estado == 'entrega_parcial') return 'Parcial';
  return 'Pendiente';
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  return <String>[];
}

String _text(dynamic value, [String fallback = '-']) {
  final s = value?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

String _formatTimestamp(dynamic value) {
  if (value is Timestamp) return DateFormat('dd/MM/yyyy HH:mm').format(value.toDate());
  return '-';
}

bool _isDeleted(Map<String, dynamic> data) => data['deleted'] == true;


Future<void> _openExternal(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _mapsUrlForQuery(String query) {
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
}

String _mapsUrlForCoords(double lat, double lng) {
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}


String? _buildDestinationMapLink(Map<String, dynamic> data) {
  final mapLink = _text(data['mapLink'], '');
  if (mapLink.isNotEmpty) return mapLink;
  final lat = data['destinationLat'];
  final lng = data['destinationLng'];
  if (lat != null && lng != null) return _mapsUrlForCoords((lat as num).toDouble(), (lng as num).toDouble());
  final address = _text(data['direccionTexto'], '');
  if (address.isNotEmpty) return _mapsUrlForQuery(address);
  return null;
}

class OrdersPage extends StatelessWidget {
  final AppUserProfile profile;

  const OrdersPage({super.key, required this.profile});

  bool _isPending(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? '').toString();
    final progress = (data['deliveryProgress'] ?? '').toString();
    return !_isDeleted(data) && (estado == 'pendiente_programacion' || estado == 'entrega_parcial' || progress == 'parcial');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final docs = (snapshot.data?.docs ?? []).where((doc) => _isPending(doc.data())).toList();
        docs.sort((a, b) {
          final da = a.data();
          final db = b.data();
          final orderA = (da['dispatchOrder'] is num) ? (da['dispatchOrder'] as num).toInt() : 999999;
          final orderB = (db['dispatchOrder'] is num) ? (db['dispatchOrder'] as num).toInt() : 999999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          final ta = da['createdAt'];
          final tb = db['createdAt'];
          if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
          return 0;
        });

        if (docs.isEmpty) return const Center(child: Text('No hay pedidos pendientes'));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Pedidos pendientes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final estado = (data['estado'] ?? '').toString();
              final progress = (data['deliveryProgress'] ?? '').toString();
              final displayCode = _text(data['orderNumber'] ?? data['orderDisplayCode'] ?? data['invoiceNumber'] ?? doc.id, 'SIN NÚMERO');
              final priority = _text(data['prioridad'], 'media').toUpperCase();
              final statusColor = _statusColor(estado, progress);
              final statusLabel = _statusLabel(estado, progress);
              final cliente = _text(data['clienteNombreSnapshot']);
              final direccion = _text(data['direccionTexto']);
              final articlesSummary = _text(
                data['invoiceItemsText'] ?? data['itemsSummary'] ?? data['deliverySummary'],
                '-',
              );
              final observaciones = _text(data['observaciones'], '');
              final hasPdfs = _stringList(data['invoicePdfUrls']).isNotEmpty || _text(data['pdfUrl'], '').isNotEmpty;
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        runSpacing: 8,
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(displayCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusColor.withOpacity(0.45)),
                            ),
                            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999)),
                            child: Text(priority, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          if (data['dispatchOrder'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                              child: Text('Orden ${data['dispatchOrder']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(cliente, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('📍 $direccion'),
                      const SizedBox(height: 8),
                      Text('📦 Artículos: $articlesSummary'),
                      if (observaciones.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('📝 $observaciones'),
                      ],
                      if (progress == 'parcial' || estado == 'entrega_parcial') ...[
                        const SizedBox(height: 8),
                        const Text('⚠ Entrega parcial registrada', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OrderDetailFirestorePage(orderId: doc.id, profile: profile)),
                              ),
                              child: const Text('Ver'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () async {
                                final mapLink = _buildDestinationMapLink(data);
                                if (mapLink != null) await _openExternal(mapLink);
                              },
                              child: const Text('Maps'),
                            ),
                          ),
                          if (hasPdfs) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OrderDetailFirestorePage(orderId: doc.id, profile: profile)),
                                ),
                                child: const Text('PDFs'),
                              ),
                            ),
                          ],
                          if (profile.canDeleteOrders) ...[
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar pedido',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Eliminar pedido?'),
                                    content: Text('Se eliminará el pedido de $cliente. Esta acción se puede deshacer desde la base de datos.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                                if (!confirmed) return;
                                await FirebaseFirestore.instance.collection('orders').doc(doc.id).update({
                                  'deleted': true,
                                  'deletedAt': FieldValue.serverTimestamp(),
                                  'deletedBy': profile.uid,
                                  'deletedByName': profile.fullName,
                                });
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pedido eliminado')),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
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

class OrderDetailFirestorePage extends StatelessWidget {
  final String orderId;
  final AppUserProfile profile;

  const OrderDetailFirestorePage({super.key, required this.orderId, required this.profile});

  Future<void> _softDeleteOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar pedido'),
            content: const Text('Se hará un borrado lógico. El pedido dejará de verse en las pantallas normales.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': profile.uid,
      'deletedByName': profile.fullName,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido eliminado lógicamente')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        actions: [
          if (profile.canDeleteOrders)
            IconButton(
              tooltip: 'Eliminar pedido',
              onPressed: () => _softDeleteOrder(context),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final doc = snapshot.data;
          if (doc == null || !doc.exists || doc.data() == null) return const Center(child: Text('Pedido no encontrado'));
          final data = doc.data()!;
          final estado = (data['estado'] ?? '').toString();
          final progress = (data['deliveryProgress'] ?? '').toString();
          final statusColor = _statusColor(estado, progress);
          final statusLabel = _statusLabel(estado, progress);
          final orderCode = _text(data['orderNumber'] ?? data['orderDisplayCode'] ?? data['invoiceNumber'] ?? doc.id);
          final invoicePdfUrls = _stringList(data['invoicePdfUrls']);
          final legacyPdf = _text(data['pdfUrl'], '');
          if (invoicePdfUrls.isEmpty && legacyPdf.isNotEmpty) invoicePdfUrls.add(legacyPdf);
          final invoicePhotoUrls = _stringList(data['invoicePhotoUrls']);
          final articlesSummary = _text(
            data['invoiceItemsText'] ?? data['itemsSummary'] ?? data['deliverySummary'],
            '-',
          );
          final destinationMapLink = _buildDestinationMapLink(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(orderCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: statusColor.withOpacity(0.45)),
                          ),
                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                        ),
                        if (data['dispatchOrder'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                            child: Text('Orden ${data['dispatchOrder']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        if (data['hasPartialDeliveries'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                            child: const Text('Tuvo parciales', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Información general', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Cliente: ${_text(data['clienteNombreSnapshot'])}'),
                    Text('Factura: ${_text(data['invoiceNumber'])}'),
                    Text('Contacto: ${_text(data['contactName'])}'),
                    Text('Teléfono: ${_text(data['contactPhone'])}'),
                    Text('Dirección: ${_text(data['direccionTexto'])}'),
                    Text('Prioridad: ${_text(data['prioridad'])}'),
                    Text('Fecha compromiso: ${_formatTimestamp(data['committedDate'])}'),
                    Text('Creado: ${_formatTimestamp(data['createdAt'])}'),
                    if (_text(data['observaciones'], '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Observaciones: ${_text(data['observaciones'])}'),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (destinationMapLink != null)
                          FilledButton.icon(onPressed: () => _openExternal(destinationMapLink), icon: const Icon(Icons.map_outlined), label: const Text('Abrir en Maps')),
                      ],
                    ),
                  ],
                ),
              ),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Artículos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(articlesSummary),
                  ],
                ),
              ),
              if (invoicePdfUrls.isNotEmpty)
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Facturas PDF', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...invoicePdfUrls.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton.tonalIcon(
                              onPressed: () => _openExternal(entry.value),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: Text('Abrir PDF ${entry.key + 1}'),
                            ),
                          )),
                    ],
                  ),
                ),
              if (invoicePhotoUrls.isNotEmpty)
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fotos de factura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: invoicePhotoUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final url = invoicePhotoUrls[index];
                            return GestureDetector(
                              onTap: () => _openExternal(url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 220,
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: const Text('No se pudo cargar'),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              _DeliveryHistorySection(orderId: orderId, profile: profile),
              if (profile.canCloseDelivery) DeliveryEvidencePanel(orderId: orderId, profile: profile, orderStatus: estado),
            ],
          );
        },
      ),
    );
  }
}

class _DeliveryHistorySection extends StatelessWidget {
  final String orderId;
  final AppUserProfile profile;

  const _DeliveryHistorySection({required this.orderId, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('delivery_events').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, eventsSnapshot) {
        final events = (eventsSnapshot.data?.docs ?? []).where((e) => e.data()['deleted'] != true).toList();
        if (events.isEmpty) return const SizedBox.shrink();
        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Historial de entregas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...events.map((e) => _DeliveryEventCard(orderId: orderId, eventDoc: e, profile: profile)),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryEventCard extends StatelessWidget {
  final String orderId;
  final QueryDocumentSnapshot<Map<String, dynamic>> eventDoc;
  final AppUserProfile profile;

  const _DeliveryEventCard({required this.orderId, required this.eventDoc, required this.profile});

  Future<void> _deleteEvent(BuildContext context) async {
    if (kLocalOnlyMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kLocalOnlyWriteBlockedMessage)),
      );
      return;
    }
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar entrega'),
            content: const Text('Se ocultará este evento del historial visible, manteniendo trazabilidad.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await eventDoc.reference.update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': profile.uid,
      'deletedByName': profile.fullName,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrega eliminada lógicamente')));
  }

  @override
  Widget build(BuildContext context) {
    final ev = eventDoc.data();
    final result = _text(ev['result']);
    final receiver = _text(ev['receiverName']);
    final notes = _text(ev['notes']);
    final createdAt = _formatTimestamp(ev['createdAt']);
    final photoUrls = _stringList(ev['photoUrls']);
    final singlePhoto = _text(ev['photoUrl'], '');
    if (photoUrls.isEmpty && singlePhoto.isNotEmpty) photoUrls.add(singlePhoto);
    final adminExtraPhotos = _stringList(ev['adminExtraPhotoUrls']);
    final eventMapLink = _text(ev['mapLink'], '');
    final eventColor = switch (result) {
      'entregado' => Colors.green,
      'parcial' => Colors.orange,
      'fallido' => Colors.red,
      _ => Colors.blueGrey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: eventColor.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                child: Text(result.toUpperCase(), style: TextStyle(color: eventColor, fontWeight: FontWeight.w600)),
              ),
              Text(createdAt),
            ],
          ),
          const SizedBox(height: 8),
          Text('Recibido por: $receiver'),
          if (notes != '-') ...[
            const SizedBox(height: 4),
            Text('Observaciones: $notes'),
          ],
          if (photoUrls.isNotEmpty || adminExtraPhotos.isNotEmpty || eventMapLink.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...photoUrls.asMap().entries.map((entry) => FilledButton.tonalIcon(
                      onPressed: () => _openExternal(entry.value),
                      icon: const Icon(Icons.photo_outlined),
                      label: Text('Foto ${entry.key + 1}'),
                    )),
                ...adminExtraPhotos.asMap().entries.map((entry) => FilledButton.tonalIcon(
                      onPressed: () => _openExternal(entry.value),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('Adjunta admin ${entry.key + 1}'),
                    )),
                if (eventMapLink.isNotEmpty)
                  FilledButton.tonalIcon(onPressed: () => _openExternal(eventMapLink), icon: const Icon(Icons.location_on_outlined), label: const Text('Abrir ubicación')),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.canAddAdminEvidence && result == 'entregado')
                _AddAdminEvidenceButton(orderId: orderId, eventDoc: eventDoc, profile: profile),
              if (profile.canDeleteDeliveryEvents)
                OutlinedButton.icon(onPressed: () => _deleteEvent(context), icon: const Icon(Icons.delete_outline), label: const Text('Eliminar entrega')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAdminEvidenceButton extends StatefulWidget {
  final String orderId;
  final QueryDocumentSnapshot<Map<String, dynamic>> eventDoc;
  final AppUserProfile profile;

  const _AddAdminEvidenceButton({required this.orderId, required this.eventDoc, required this.profile});

  @override
  State<_AddAdminEvidenceButton> createState() => _AddAdminEvidenceButtonState();
}

class _AddAdminEvidenceButtonState extends State<_AddAdminEvidenceButton> {
  bool _loading = false;

  Future<void> _pickAndUpload() async {
    if (kLocalOnlyMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kLocalOnlyWriteBlockedMessage)),
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (picked == null || picked.files.single.bytes == null) return;
    setState(() => _loading = true);
    try {
      final bytes = picked.files.single.bytes!;
      final name = picked.files.single.name;
      final ref = FirebaseStorage.instance.ref().child('delivery_admin_evidence').child('${DateTime.now().millisecondsSinceEpoch}_$name');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await widget.eventDoc.reference.update({
        'adminExtraPhotoUrls': FieldValue.arrayUnion([url]),
        'lastAdminEvidenceAt': FieldValue.serverTimestamp(),
        'lastAdminEvidenceByUid': widget.profile.uid,
        'lastAdminEvidenceByName': widget.profile.fullName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto adicional agregada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo adjuntar la foto: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _loading ? null : _pickAndUpload,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: Text(_loading ? 'Subiendo...' : 'Adjuntar foto admin'),
    );
  }
}

class DeliveryEvidencePanel extends StatefulWidget {
  final String orderId;
  final AppUserProfile profile;
  final String orderStatus;

  const DeliveryEvidencePanel({super.key, required this.orderId, required this.profile, required this.orderStatus});

  @override
  State<DeliveryEvidencePanel> createState() => _DeliveryEvidencePanelState();
}

class _DeliveryEvidencePanelState extends State<DeliveryEvidencePanel> {
  final _notes = TextEditingController();
  final _receiver = TextEditingController();
  String result = 'entregado';
  final List<Uint8List> _photoBytesList = <Uint8List>[];
  final List<String> _photoNameList = <String>[];
  double? currentLat;
  double? currentLng;
  String? currentMapLink;
  bool loadingLocation = false;
  bool saving = false;

  bool get _requiresStrictEvidence => widget.profile.role == AppRole.logistica;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    _photoBytesList.add(bytes);
    _photoNameList.add(file.name);
    if (mounted) setState(() {});
  }

  Future<void> _captureLocation() async {
    setState(() => loadingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _toast('La ubicación del dispositivo está desactivada.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _toast('No se otorgó permiso de ubicación.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      currentLat = pos.latitude;
      currentLng = pos.longitude;
      currentMapLink = _mapsUrlForCoords(currentLat!, currentLng!);
      _toast('Ubicación capturada correctamente.');
    } catch (_) {
      _toast('No fue posible obtener la ubicación actual.');
    } finally {
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  bool _validateBeforeSave() {
    if (!_requiresStrictEvidence) return true;
    if (_photoBytesList.isEmpty) {
      _toast('Para usuarios de logística es obligatorio sacar al menos una foto antes de guardar.');
      return false;
    }
    if (currentLat == null || currentLng == null) {
      _toast('Para usuarios de logística es obligatorio capturar ubicación antes de guardar.');
      return false;
    }
    return true;
  }

  Future<void> _saveDelivery() async {
    if (kLocalOnlyMode) {
      _toast(kLocalOnlyWriteBlockedMessage);
      return;
    }
    if (!_validateBeforeSave()) return;

    String? logisticsDayLogId;
    String? activeTruckId;
    String? activeTruckLabel;
    if (requiresAndroidLogisticsDayControl(widget.profile)) {
      final openDayQuery = await FirebaseFirestore.instance
          .collection('logistics_day_logs')
          .where('userUid', isEqualTo: widget.profile.uid)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();
      final dayDoc = openDayQuery.docs.isNotEmpty ? openDayQuery.docs.first : null;
      final dayData = dayDoc?.data();
      if (!isOpenLogisticsDay(dayData)) {
        _toast('Primero tenés que iniciar la jornada con camión y km iniciales.');
        return;
      }
      logisticsDayLogId = dayDoc!.id;
      activeTruckId = dayData?['truckId']?.toString();
      activeTruckLabel = dayData?['truckLabel']?.toString();
    }

    setState(() => saving = true);
    try {
      final photoUrls = <String>[];
      final pendingLocalPhotoNames = <String>[];
      for (int i = 0; i < _photoBytesList.length; i++) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('delivery_photos')
              .child('${DateTime.now().millisecondsSinceEpoch}_${i}_${_photoNameList[i]}');
          await ref.putData(
            _photoBytesList[i],
            SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrls.add(await ref.getDownloadURL());
        } catch (_) {
          pendingLocalPhotoNames.add(_photoNameList[i]);
        }
      }

      final hasPendingLocalUploads = pendingLocalPhotoNames.isNotEmpty;

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      final eventsRef = orderRef.collection('delivery_events').doc();
      final newStatus = switch (result) {
        'entregado' => 'entregado',
        'parcial' => 'entrega_parcial',
        'fallido' => 'entrega_fallida',
        _ => 'pendiente_programacion',
      };
      final deliveryProgress = switch (result) {
        'entregado' => 'completo',
        'parcial' => 'parcial',
        'fallido' => 'fallido',
        _ => 'sin_entregar',
      };
      final batch = FirebaseFirestore.instance.batch();
      batch.set(eventsRef, {
        'result': result,
        'receiverName': _receiver.text.trim().isEmpty ? null : _receiver.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'lat': currentLat,
        'lng': currentLng,
        'mapLink': currentMapLink,
        'photoUrl': photoUrls.isEmpty ? null : photoUrls.first,
        'photoUrls': photoUrls,
        'pendingLocalPhotoNames':
            pendingLocalPhotoNames.isEmpty ? null : pendingLocalPhotoNames,
        'hasPendingLocalUploads': hasPendingLocalUploads,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.profile.uid,
        'createdByName': widget.profile.fullName,
        'logisticsDayLogId': logisticsDayLogId,
        'truckId': activeTruckId,
        'truckLabel': activeTruckLabel,
        'deleted': false,
      });
      batch.update(orderRef, {
        'estado': newStatus,
        'deliveryProgress': deliveryProgress,
        'deliveryReceiverName': _receiver.text.trim().isEmpty ? null : _receiver.text.trim(),
        'deliveryNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'deliveryLat': currentLat,
        'deliveryLng': currentLng,
        'deliveryMapLink': currentMapLink,
        'deliveryPhotoUrl': photoUrls.isEmpty ? null : photoUrls.first,
        'deliveryPhotoUrls': photoUrls,
        'hasPendingLocalUploads': hasPendingLocalUploads,
        'pendingLocalDeliveryPhotoNames':
          hasPendingLocalUploads ? pendingLocalPhotoNames : null,
        'lastDeliveryUpdateAt': FieldValue.serverTimestamp(),
        'lastDeliveryResult': result,
        'activeTruckId': activeTruckId,
        'activeTruckLabel': activeTruckLabel,
        'logisticsDayLogId': logisticsDayLogId,
        'deliveryEventCount': FieldValue.increment(1),
        if (result == 'parcial') 'hasPartialDeliveries': true,
        if (result == 'entregado') 'deliveredAt': FieldValue.serverTimestamp(),
        if (result == 'entregado') 'finalDeliveredAt': FieldValue.serverTimestamp(),
        if (result == 'fallido') 'deliveryFailedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
        final msg = hasPendingLocalUploads
          ? 'Entrega guardada localmente. Quedaron fotos pendientes de subir.'
          : 'Resultado de entrega guardado';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _receiver.clear();
      _notes.clear();
      _photoBytesList.clear();
      _photoNameList.clear();
      currentLat = null;
      currentLng = null;
      currentMapLink = null;
      result = 'entregado';
      setState(() {});
    } catch (e) {
      _toast('Error al guardar la entrega: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _notes.dispose();
    _receiver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Acciones de entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: result,
            decoration: const InputDecoration(labelText: 'Resultado'),
            items: const [
              DropdownMenuItem(value: 'entregado', child: Text('Entrega completa')),
              DropdownMenuItem(value: 'parcial', child: Text('Entrega parcial')),
              DropdownMenuItem(value: 'fallido', child: Text('Entrega fallida')),
            ],
            onChanged: (v) => setState(() => result = v ?? 'entregado'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _receiver, decoration: const InputDecoration(labelText: 'Recibido por')),
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones de entrega')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: saving ? null : _pickPhoto, icon: const Icon(Icons.camera_alt_outlined), label: Text(_photoNameList.isEmpty ? 'Sacar foto' : 'Agregar otra foto')),
              OutlinedButton.icon(onPressed: saving || loadingLocation ? null : _captureLocation, icon: const Icon(Icons.my_location_outlined), label: Text(loadingLocation ? 'Capturando...' : 'Capturar ubicación')),
              if (currentMapLink != null)
                FilledButton.tonalIcon(onPressed: () => _openExternal(currentMapLink!), icon: const Icon(Icons.location_on_outlined), label: const Text('Ver ubicación')),
            ],
          ),
          if (_photoNameList.isNotEmpty || (currentLat != null && currentLng != null)) ...[
            const SizedBox(height: 12),
            if (_photoNameList.isNotEmpty) Text('Fotos: ${_photoNameList.join(', ')}'),
            if (currentLat != null && currentLng != null) Text('Ubicación: ${currentLat!.toStringAsFixed(6)}, ${currentLng!.toStringAsFixed(6)}'),
          ],
          if (_requiresStrictEvidence) ...[
            const SizedBox(height: 12),
            const Text('Para usuarios de logística, foto y ubicación son obligatorias.', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: saving ? null : _saveDelivery, icon: const Icon(Icons.check_circle_outline), label: Text(saving ? 'Guardando...' : 'Guardar resultado de entrega')),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
