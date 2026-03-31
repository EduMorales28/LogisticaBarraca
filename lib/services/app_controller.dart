import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'storage_service.dart';

class AppController extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  AppController(this._storage);

  AppData _data = AppData.empty();
  bool initialized = false;
  AppUser? currentUser;
  String? lastError;
  bool isSyncPending = false;

  AppData get data => _data;
  List<AppUser> get users => _data.users;
  List<Customer> get customers => _data.customers;
  List<Sale> get sales => _data.sales;
  List<DeliveryOrder> get orders => _data.orders;
  List<Attachment> get attachments => _data.attachments;

  Future<void> initialize() async {
    _data = await _storage.load();
    initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    isSyncPending = true;
    notifyListeners();
    await _storage.save(_data);
    isSyncPending = false;
    notifyListeners();
  }

  bool login(String username, String password) {
    final found = users.firstWhereOrNull(
      (u) => u.username.trim() == username.trim() && u.password == password && u.active,
    );
    if (found == null) {
      lastError = 'Usuario o contraseña incorrectos';
      notifyListeners();
      return false;
    }
    currentUser = found;
    lastError = null;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  AppUser? userById(String? id) => users.firstWhereOrNull((u) => u.id == id);
  Customer? customerById(String? id) => customers.firstWhereOrNull((c) => c.id == id);
  Sale? saleById(String? id) => sales.firstWhereOrNull((s) => s.id == id);
  Attachment? attachmentById(String? id) => attachments.firstWhereOrNull((a) => a.id == id);

  Future<void> addUser({
    required String username,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final user = AppUser(
      id: _uuid.v4(),
      username: username.trim(),
      password: password,
      fullName: fullName.trim(),
      role: role,
      active: true,
      createdAt: DateTime.now(),
    );
    _data = AppData(
      users: [...users, user],
      customers: customers,
      sales: sales,
      orders: orders,
      attachments: attachments,
    );
    await _persist();
  }

  Future<void> updateUser(AppUser updated) async {
    _data = AppData(
      users: users.map((u) => u.id == updated.id ? updated : u).toList(),
      customers: customers,
      sales: sales,
      orders: orders,
      attachments: attachments,
    );
    await _persist();
  }

  Future<void> addCustomer(Customer customer) async {
    _data = AppData(
      users: users,
      customers: [...customers, customer],
      sales: sales,
      orders: orders,
      attachments: attachments,
    );
    await _persist();
  }

  Future<String> addAttachment({
    required AttachmentType type,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final current = currentUser;
    if (current == null) throw Exception('Sesión no iniciada');
    final attachment = Attachment(
      id: _uuid.v4(),
      type: type,
      fileName: fileName,
      mimeType: mimeType,
      base64Data: base64Encode(bytes),
      createdAt: DateTime.now(),
      createdByUserId: current.id,
    );
    _data = AppData(
      users: users,
      customers: customers,
      sales: sales,
      orders: orders,
      attachments: [...attachments, attachment],
    );
    await _persist();
    return attachment.id;
  }

  Future<void> addSaleAndOrder({
    required String invoiceNumber,
    required Customer customer,
    required DateTime committedDate,
    required String contactName,
    required String contactPhone,
    required String address,
    required String? mapLink,
    required double? destinationLat,
    required double? destinationLng,
    required String? zone,
    required String? notes,
    required String? itemsSummary,
    required int priority,
    required int totalTrips,
    required int counterPickupUnits,
    String? invoiceAttachmentId,
  }) async {
    final current = currentUser;
    if (current == null) throw Exception('Sesión no iniciada');
    final customerExists = customers.any((c) => c.id == customer.id);
    final customerId = customerExists ? customer.id : _uuid.v4();
    final savedCustomer = customerExists
        ? customer
        : Customer(
            id: customerId,
            name: customer.name,
            phone: customer.phone,
            altPhone: customer.altPhone,
            address: customer.address,
            mapLink: customer.mapLink,
            lat: customer.lat,
            lng: customer.lng,
            notes: customer.notes,
          );

    final sale = Sale(
      id: _uuid.v4(),
      invoiceNumber: invoiceNumber,
      saleDate: DateTime.now(),
      customerId: customerId,
      notes: notes,
      invoiceAttachmentId: invoiceAttachmentId,
      itemsSummary: itemsSummary,
    );

    final order = DeliveryOrder(
      id: _uuid.v4(),
      saleId: sale.id,
      customerId: customerId,
      address: address,
      contactName: contactName,
      contactPhone: contactPhone,
      mapLink: mapLink,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      zone: zone,
      notes: notes,
      deliveryItemsSummary: itemsSummary,
      committedDate: committedDate,
      priority: priority,
      totalTrips: totalTrips,
      counterPickupUnits: counterPickupUnits,
      status: OrderStatus.pendienteProgramacion,
      deliveries: const [],
      statusHistory: [
        StatusHistoryItem(
          createdAt: DateTime.now(),
          userId: current.id,
          from: OrderStatus.borrador,
          to: OrderStatus.pendienteProgramacion,
          notes: 'Pedido creado desde mostrador',
        )
      ],
      createdAt: DateTime.now(),
      createdByUserId: current.id,
    );

    _data = AppData(
      users: users,
      customers: customerExists ? customers : [...customers, savedCustomer],
      sales: [...sales, sale],
      orders: [...orders, order],
      attachments: attachments,
    );
    await _persist();
  }

  Future<void> updateOrder(DeliveryOrder updated) async {
    _data = AppData(
      users: users,
      customers: customers,
      sales: sales,
      orders: orders.map((o) => o.id == updated.id ? updated : o).toList(),
      attachments: attachments,
    );
    await _persist();
  }

  Future<void> transitionOrder({
    required DeliveryOrder order,
    required OrderStatus to,
    String? notes,
  }) async {
    final current = currentUser;
    if (current == null) return;
    final updated = order.copyWith(
      status: to,
      statusHistory: [
        ...order.statusHistory,
        StatusHistoryItem(
          createdAt: DateTime.now(),
          userId: current.id,
          from: order.status,
          to: to,
          notes: notes,
        ),
      ],
    );
    await updateOrder(updated);
  }

  Future<void> registerDelivery({
    required DeliveryOrder order,
    required DeliveryResult result,
    String? notes,
    String? receiverName,
    String? photoAttachmentId,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryMapLink,
  }) async {
    final current = currentUser;
    if (current == null) return;
    final record = DeliveryRecord(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      createdByUserId: current.id,
      result: result,
      notes: notes,
      receiverName: receiverName,
      photoAttachmentId: photoAttachmentId,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      deliveryMapLink: deliveryMapLink,
    );

    OrderStatus nextStatus;
    switch (result) {
      case DeliveryResult.entregado:
        nextStatus = (order.deliveries.length + 1) >= order.totalTrips
            ? OrderStatus.entregado
            : OrderStatus.entregaParcial;
        break;
      case DeliveryResult.parcial:
        nextStatus = OrderStatus.entregaParcial;
        break;
      case DeliveryResult.fallido:
        nextStatus = OrderStatus.entregaFallida;
        break;
    }

    final updated = order.copyWith(
      status: nextStatus,
      deliveries: [...order.deliveries, record],
      statusHistory: [
        ...order.statusHistory,
        StatusHistoryItem(
          createdAt: DateTime.now(),
          userId: current.id,
          from: order.status,
          to: nextStatus,
          notes: notes,
        )
      ],
    );
    await updateOrder(updated);
  }

  List<DeliveryOrder> filteredOrders({
    String query = '',
    Set<OrderStatus>? statuses,
  }) {
    final q = query.trim().toLowerCase();
    return orders.where((o) {
      final customer = customerById(o.customerId);
      final matchesStatus = statuses == null || statuses.isEmpty || statuses.contains(o.status);
      final matchesQuery = q.isEmpty ||
          customer?.name.toLowerCase().contains(q) == true ||
          o.address.toLowerCase().contains(q) ||
          o.contactPhone.toLowerCase().contains(q) ||
          saleById(o.saleId)?.invoiceNumber.toLowerCase().contains(q) == true;
      return matchesStatus && matchesQuery;
    }).sorted((a, b) {
      final byDate = a.committedDate.compareTo(b.committedDate);
      if (byDate != 0) return byDate;
      return a.priority.compareTo(b.priority);
    });
  }

  bool canManageUsers() => currentUser?.role == UserRole.admin;
  bool canCreateOrders() => currentUser?.role == UserRole.admin || currentUser?.role == UserRole.ventas;
  bool canOperateLogistics() => currentUser?.role == UserRole.admin || currentUser?.role == UserRole.logistica;
}
