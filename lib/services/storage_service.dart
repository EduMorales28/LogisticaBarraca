import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class StorageService {
  static const _key = 'logistica_barraca_data_v1';

  Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      final seeded = _seedData();
      await save(seeded);
      return seeded;
    }
    return AppData.decode(raw);
  }

  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.encode());
  }

  AppData _seedData() {
    final admin = AppUser(
      id: 'u-admin',
      username: 'admin',
      password: 'admin123',
      fullName: 'Administrador General',
      role: UserRole.admin,
      active: true,
      createdAt: DateTime.now(),
    );
    final ventas = AppUser(
      id: 'u-ventas',
      username: 'ventas',
      password: 'ventas123',
      fullName: 'Mostrador Principal',
      role: UserRole.ventas,
      active: true,
      createdAt: DateTime.now(),
    );
    final logistica = AppUser(
      id: 'u-logistica',
      username: 'logistica',
      password: 'logistica123',
      fullName: 'Encargado de Logística',
      role: UserRole.logistica,
      active: true,
      createdAt: DateTime.now(),
    );
    final customer = Customer(
      id: 'c1',
      name: 'Estancia del Lago',
      phone: '094000001',
      address: 'Ruta 5 km 123, Sarandí Grande',
      mapLink: 'https://maps.google.com',
      notes: 'Entrar por portón norte.',
    );
    final sale = Sale(
      id: 's1',
      invoiceNumber: 'A-000123',
      saleDate: DateTime.now(),
      customerId: customer.id,
      notes: 'Venta semilla de demo',
      invoiceAttachmentId: null,
      itemsSummary: '10 bloques de hormigón\n6 varillas 8 mm\n1 m3 arena fina',
    );
    final order = DeliveryOrder(
      id: 'o1',
      saleId: sale.id,
      customerId: customer.id,
      address: customer.address,
      contactName: customer.name,
      contactPhone: customer.phone,
      mapLink: customer.mapLink,
      destinationLat: -33.3500,
      destinationLng: -56.5200,
      zone: 'Sarandí Norte',
      notes: 'Llevar primero bloques y después varillas.',
      deliveryItemsSummary: '10 bloques de hormigón\n6 varillas 8 mm\n1 m3 arena fina',
      committedDate: DateTime.now().add(const Duration(days: 1)),
      priority: 2,
      totalTrips: 2,
      counterPickupUnits: 1,
      status: OrderStatus.programado,
      deliveries: const [],
      statusHistory: [
        StatusHistoryItem(
          createdAt: DateTime.now(),
          userId: admin.id,
          from: OrderStatus.borrador,
          to: OrderStatus.programado,
          notes: 'Pedido creado desde venta demo',
        ),
      ],
      createdAt: DateTime.now(),
      createdByUserId: ventas.id,
      assignedUserId: logistica.id,
    );
    return AppData(
      users: [admin, ventas, logistica],
      customers: [customer],
      sales: [sale],
      orders: [order],
      attachments: [],
    );
  }
}
