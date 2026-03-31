import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../authz.dart';
import 'orders_page.dart';

class DispatchPlanningPage extends StatelessWidget {
  const DispatchPlanningPage({super.key});

  bool _isDispatchPending(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? '').toString();
    final progress = (data['deliveryProgress'] ?? '').toString();
    final deleted = data['deleted'] == true;

    return !deleted &&
        (estado == 'pendiente_programacion' ||
            estado == 'entrega_parcial' ||
            progress == 'parcial');
  }

  @override
  Widget build(BuildContext context) {
    final profile = CurrentAppUserScope.of(context);

    if (!profile.canManageDispatch) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tu usuario no tiene permiso para programar la logística.'),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((doc) => _isDispatchPending(doc.data()))
            .toList();

        docs.sort((a, b) {
          final da = a.data();
          final db = b.data();

          final orderA = (da['dispatchOrder'] is num)
              ? (da['dispatchOrder'] as num).toInt()
              : 999999;
          final orderB = (db['dispatchOrder'] is num)
              ? (db['dispatchOrder'] as num).toInt()
              : 999999;

          if (orderA != orderB) return orderA.compareTo(orderB);

          final ta = da['createdAt'];
          final tb = db['createdAt'];

          if (ta is Timestamp && tb is Timestamp) {
            return ta.compareTo(tb);
          }

          return 0;
        });

        if (docs.isEmpty) {
          return const Center(child: Text('No hay pedidos para programar.'));
        }

        return _DispatchPlanningList(docs: docs, profile: profile);
      },
    );
  }
}

class _DispatchPlanningList extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final AppUserProfile profile;

  const _DispatchPlanningList({
    required this.docs,
    required this.profile,
  });

  @override
  State<_DispatchPlanningList> createState() => _DispatchPlanningListState();
}

class _DispatchPlanningListState extends State<_DispatchPlanningList> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.docs);
  }

  @override
  void didUpdateWidget(covariant _DispatchPlanningList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = List.of(widget.docs);
  }

  Future<void> _persistOrder() async {
    setState(() => _saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < _items.length; i++) {
        batch.update(_items[i].reference, {
          'dispatchOrder': i + 1,
          'dispatchUpdatedAt': FieldValue.serverTimestamp(),
          'dispatchUpdatedByUid': widget.profile.uid,
          'dispatchUpdatedByName': widget.profile.fullName,
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden de despacho actualizada')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Programación logística',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Arrastrá los pedidos para cambiar la prioridad real de despacho.'),
        const SizedBox(height: 12),

        Card(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final doc = _items[index];
              final data = doc.data();

              final orderNumber = (data['orderNumber'] ??
                      data['invoiceNumber'] ??
                      doc.id)
                  .toString();

              return ListTile(
                key: ValueKey(doc.id),
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(orderNumber),
                subtitle: Text(
                  '${data['clienteNombreSnapshot'] ?? '-'}\n'
                  '${data['direccionTexto'] ?? '-'}',
                ),
                trailing: const Icon(Icons.drag_handle),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailFirestorePage(
                      orderId: doc.id,
                      profile: widget.profile,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _saving ? null : _persistOrder,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : 'Guardar orden de despacho'),
        ),
      ],
    );
  }
}