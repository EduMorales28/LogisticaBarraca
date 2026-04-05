import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../authz.dart';
import '../services/logistics_day_service.dart';
import 'orders_page.dart';

class ReportsPage extends StatefulWidget {
  final AppUserProfile profile;

  const ReportsPage({super.key, required this.profile});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime? _selectedDay;
  String _vehicleFilter = 'all';

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('es', 'UY'),
    );
    if (picked == null) return;
    setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
  }

  void _clearDayFilter() {
    setState(() => _selectedDay = null);
  }

  bool _sameDay(DateTime date, DateTime selected) {
    return date.year == selected.year && date.month == selected.month && date.day == selected.day;
  }

  DateTime? _orderDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final committedDate = data['committedDate'];
    if (committedDate is Timestamp) return committedDate.toDate();
    return null;
  }

  DateTime? _logDate(Map<String, dynamic> data) {
    final initialAt = data['initialAt'];
    if (initialAt is Timestamp) return initialAt.toDate();
    final dateValue = data['dateValue'];
    if (dateValue is Timestamp) return dateValue.toDate();
    return null;
  }

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    final text = raw.toString().trim();
    if (text.isEmpty) return 0;
    final normalized = text.replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  int _extractKm(Map<String, dynamic> log) {
    final totalKmRaw = log['totalKm'];
    if (totalKmRaw is num) return totalKmRaw.toInt();
    final initial = (log['initialKm'] as num?)?.toInt();
    final finalKm = (log['finalKm'] as num?)?.toInt();
    if (initial == null || finalKm == null) return 0;
    return finalKm >= initial ? finalKm - initial : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Solo administradores pueden ver reportes.'),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Reportes',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _selectedDay == null
                    ? 'Filtrar por día'
                    : DateFormat('dd/MM/yyyy').format(_selectedDay!),
              ),
            ),
            if (_selectedDay != null)
              OutlinedButton.icon(
                onPressed: _clearDayFilter,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Quitar filtro'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _OrdersReportSection(
          profile: widget.profile,
          selectedDay: _selectedDay,
          orderDate: _orderDate,
          sameDay: _sameDay,
          parseAmount: _parseAmount,
        ),
        const SizedBox(height: 14),
        _VehiclesReportSection(
          selectedDay: _selectedDay,
          selectedVehicle: _vehicleFilter,
          onVehicleChanged: (value) => setState(() => _vehicleFilter = value),
          logDate: _logDate,
          sameDay: _sameDay,
          extractKm: _extractKm,
        ),
      ],
    );
  }
}

class _OrdersReportSection extends StatelessWidget {
  final AppUserProfile profile;
  final DateTime? selectedDay;
  final DateTime? Function(Map<String, dynamic> data) orderDate;
  final bool Function(DateTime date, DateTime selected) sameDay;
  final double Function(dynamic raw) parseAmount;

  const _OrdersReportSection({
    required this.profile,
    required this.selectedDay,
    required this.orderDate,
    required this.sameDay,
    required this.parseAmount,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final all = snapshot.data!.docs;
        final filtered = all.where((doc) {
          final data = doc.data();
          if (data['deleted'] == true) return false;
          if (selectedDay == null) return true;
          final date = orderDate(data);
          if (date == null) return false;
          return sameDay(date, selectedDay!);
        }).toList();

        filtered.sort((a, b) {
          final ad = orderDate(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = orderDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        final pedidosTotales = filtered.length;
        final entregados = filtered.where((d) => (d.data()['estado'] ?? '').toString() == 'entregado').length;
        final pendientes = filtered.where((d) {
          final estado = (d.data()['estado'] ?? '').toString();
          return estado == 'pendiente_programacion' || estado == 'entrega_parcial';
        }).length;
        final totalFacturado = filtered.fold<double>(0, (acc, d) => acc + parseAmount(d.data()['invoiceTotalAmount']));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pedidos generales y contables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricTag(label: 'Pedidos', value: '$pedidosTotales'),
                    _MetricTag(label: 'Entregados', value: '$entregados'),
                    _MetricTag(label: 'Pendientes/Parciales', value: '$pendientes'),
                    _MetricTag(label: 'Monto facturas', value: NumberFormat.currency(locale: 'es_UY', symbol: r'$').format(totalFacturado)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Pedidos del período', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  const Text('No hay pedidos para el filtro seleccionado.')
                else
                  ...filtered.map((doc) {
                    final data = doc.data();
                    final date = orderDate(data);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text((data['invoiceNumber'] ?? data['orderNumber'] ?? doc.id).toString()),
                        subtitle: Text(
                          '${(data['clienteNombreSnapshot'] ?? '-').toString()}\n'
                          'Estado: ${(data['estado'] ?? '-').toString()} · '
                          'Fecha: ${date == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(date)}\n'
                          'Monto factura: ${NumberFormat.currency(locale: 'es_UY', symbol: r'$').format(parseAmount(data['invoiceTotalAmount']))}',
                        ),
                        isThreeLine: true,
                        trailing: FilledButton.tonal(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailFirestorePage(orderId: doc.id, profile: profile),
                            ),
                          ),
                          child: const Text('Ver'),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VehiclesReportSection extends StatelessWidget {
  final DateTime? selectedDay;
  final String selectedVehicle;
  final ValueChanged<String> onVehicleChanged;
  final DateTime? Function(Map<String, dynamic> data) logDate;
  final bool Function(DateTime date, DateTime selected) sameDay;
  final int Function(Map<String, dynamic> log) extractKm;

  const _VehiclesReportSection({
    required this.selectedDay,
    required this.selectedVehicle,
    required this.onVehicleChanged,
    required this.logDate,
    required this.sameDay,
    required this.extractKm,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('logistics_day_logs').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final logs = snapshot.data!.docs.map((d) => d.data()).where((data) {
          if ((data['status'] ?? '').toString() != 'closed') return false;
          if (selectedDay != null) {
            final date = logDate(data);
            if (date == null || !sameDay(date, selectedDay!)) return false;
          }
          if (selectedVehicle != 'all' && (data['truckId'] ?? '').toString() != selectedVehicle) return false;
          return true;
        }).toList();

        final vehicleOptions = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: 'all', child: Text('Todos los vehículos')),
          ...logisticsTruckOptions.map((v) => DropdownMenuItem(value: v.id, child: Text(v.label))),
        ];

        final kmsTotales = logs.fold<int>(0, (acc, log) => acc + extractKm(log));
        final byVehicle = <String, int>{};
        final byOpenName = <String, int>{};
        final byCloseName = <String, int>{};

        for (final log in logs) {
          final km = extractKm(log);
          final truck = (log['truckLabel'] ?? 'Sin vehículo').toString();
          final openedBy = (log['openedByName'] ?? 'Sin nombre').toString();
          final closedBy = (log['closedByName'] ?? 'Sin nombre').toString();

          byVehicle[truck] = (byVehicle[truck] ?? 0) + km;
          byOpenName[openedBy] = (byOpenName[openedBy] ?? 0) + km;
          byCloseName[closedBy] = (byCloseName[closedBy] ?? 0) + km;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehículos y kilómetros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedVehicle,
                  decoration: const InputDecoration(labelText: 'Filtrar por vehículo'),
                  items: vehicleOptions,
                  onChanged: (value) => onVehicleChanged(value ?? 'all'),
                ),
                const SizedBox(height: 12),
                _MetricTag(label: 'Km recorridos', value: '$kmsTotales km'),
                const SizedBox(height: 14),
                const Text('Kilómetros por vehículo', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (byVehicle.isEmpty) const Text('No hay recorridos cerrados para el filtro seleccionado.'),
                ...byVehicle.entries.map((entry) => _SimpleLine(label: entry.key, value: '${entry.value} km')),
                const SizedBox(height: 14),
                const Text('Por persona que abre', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (byOpenName.isEmpty) const Text('Sin datos'),
                ...byOpenName.entries.map((entry) => _SimpleLine(label: entry.key, value: '${entry.value} km')),
                const SizedBox(height: 14),
                const Text('Por persona que cierra', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (byCloseName.isEmpty) const Text('Sin datos'),
                ...byCloseName.entries.map((entry) => _SimpleLine(label: entry.key, value: '${entry.value} km')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricTag extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006341).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SimpleLine extends StatelessWidget {
  final String label;
  final String value;

  const _SimpleLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
