import 'dart:convert';

enum UserRole { admin, ventas, logistica }
enum OrderStatus {
  borrador,
  pendienteProgramacion,
  programado,
  enReparto,
  entregado,
  entregaParcial,
  entregaFallida,
  reprogramado,
  cancelado,
}

enum DeliveryResult { entregado, parcial, fallido }

enum AttachmentType { facturaPdf, fotoEntrega }

String enumName(Object e) => e.toString().split('.').last;
T enumFromName<T>(Iterable<T> values, String raw) => values.firstWhere((e) => enumName(e as Object) == raw);

class AppUser {
  final String id;
  final String username;
  final String password;
  final String fullName;
  final UserRole role;
  final bool active;
  final DateTime createdAt;

  AppUser({required this.id, required this.username, required this.password, required this.fullName, required this.role, required this.active, required this.createdAt});

  AppUser copyWith({String? username, String? password, String? fullName, UserRole? role, bool? active}) => AppUser(
        id: id,
        username: username ?? this.username,
        password: password ?? this.password,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password': password,
        'fullName': fullName,
        'role': enumName(role),
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'],
        username: map['username'],
        password: map['password'],
        fullName: map['fullName'],
        role: enumFromName(UserRole.values, map['role']),
        active: map['active'] ?? true,
        createdAt: DateTime.parse(map['createdAt']),
      );
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? altPhone;
  final String address;
  final String? mapLink;
  final double? lat;
  final double? lng;
  final String? notes;

  Customer({required this.id, required this.name, required this.phone, this.altPhone, required this.address, this.mapLink, this.lat, this.lng, this.notes});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'altPhone': altPhone,
        'address': address,
        'mapLink': mapLink,
        'lat': lat,
        'lng': lng,
        'notes': notes,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'],
        name: map['name'],
        phone: map['phone'],
        altPhone: map['altPhone'],
        address: map['address'],
        mapLink: map['mapLink'],
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        notes: map['notes'],
      );
}

class Attachment {
  final String id;
  final AttachmentType type;
  final String fileName;
  final String mimeType;
  final String base64Data;
  final DateTime createdAt;
  final String createdByUserId;

  Attachment({required this.id, required this.type, required this.fileName, required this.mimeType, required this.base64Data, required this.createdAt, required this.createdByUserId});

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': enumName(type),
        'fileName': fileName,
        'mimeType': mimeType,
        'base64Data': base64Data,
        'createdAt': createdAt.toIso8601String(),
        'createdByUserId': createdByUserId,
      };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
        id: map['id'],
        type: enumFromName(AttachmentType.values, map['type']),
        fileName: map['fileName'],
        mimeType: map['mimeType'],
        base64Data: map['base64Data'],
        createdAt: DateTime.parse(map['createdAt']),
        createdByUserId: map['createdByUserId'],
      );
}

class Sale {
  final String id;
  final String invoiceNumber;
  final DateTime saleDate;
  final String customerId;
  final String? notes;
  final String? invoiceAttachmentId;
  final String? itemsSummary;

  Sale({required this.id, required this.invoiceNumber, required this.saleDate, required this.customerId, this.notes, this.invoiceAttachmentId, this.itemsSummary});

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'saleDate': saleDate.toIso8601String(),
        'customerId': customerId,
        'notes': notes,
        'invoiceAttachmentId': invoiceAttachmentId,
        'itemsSummary': itemsSummary,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'],
        invoiceNumber: map['invoiceNumber'],
        saleDate: DateTime.parse(map['saleDate']),
        customerId: map['customerId'],
        notes: map['notes'],
        invoiceAttachmentId: map['invoiceAttachmentId'],
        itemsSummary: map['itemsSummary'],
      );
}

class DeliveryRecord {
  final String id;
  final DateTime createdAt;
  final String createdByUserId;
  final DeliveryResult result;
  final String? notes;
  final String? receiverName;
  final String? photoAttachmentId;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryMapLink;

  DeliveryRecord({required this.id, required this.createdAt, required this.createdByUserId, required this.result, this.notes, this.receiverName, this.photoAttachmentId, this.deliveryLat, this.deliveryLng, this.deliveryMapLink});

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'createdByUserId': createdByUserId,
        'result': enumName(result),
        'notes': notes,
        'receiverName': receiverName,
        'photoAttachmentId': photoAttachmentId,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'deliveryMapLink': deliveryMapLink,
      };

  factory DeliveryRecord.fromMap(Map<String, dynamic> map) => DeliveryRecord(
        id: map['id'],
        createdAt: DateTime.parse(map['createdAt']),
        createdByUserId: map['createdByUserId'],
        result: enumFromName(DeliveryResult.values, map['result']),
        notes: map['notes'],
        receiverName: map['receiverName'],
        photoAttachmentId: map['photoAttachmentId'],
        deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
        deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
        deliveryMapLink: map['deliveryMapLink'],
      );
}

class StatusHistoryItem {
  final DateTime createdAt;
  final String userId;
  final OrderStatus from;
  final OrderStatus to;
  final String? notes;

  StatusHistoryItem({required this.createdAt, required this.userId, required this.from, required this.to, this.notes});

  Map<String, dynamic> toMap() => {
        'createdAt': createdAt.toIso8601String(),
        'userId': userId,
        'from': enumName(from),
        'to': enumName(to),
        'notes': notes,
      };

  factory StatusHistoryItem.fromMap(Map<String, dynamic> map) => StatusHistoryItem(
        createdAt: DateTime.parse(map['createdAt']),
        userId: map['userId'],
        from: enumFromName(OrderStatus.values, map['from']),
        to: enumFromName(OrderStatus.values, map['to']),
        notes: map['notes'],
      );
}

class DeliveryOrder {
  final String id;
  final String saleId;
  final String customerId;
  final String address;
  final String contactName;
  final String contactPhone;
  final String? mapLink;
  final double? destinationLat;
  final double? destinationLng;
  final String? zone;
  final String? notes;
  final String? deliveryItemsSummary;
  final DateTime committedDate;
  final int priority;
  final int totalTrips;
  final int counterPickupUnits;
  final OrderStatus status;
  final List<DeliveryRecord> deliveries;
  final List<StatusHistoryItem> statusHistory;
  final DateTime createdAt;
  final String createdByUserId;
  final String? assignedUserId;

  DeliveryOrder({required this.id, required this.saleId, required this.customerId, required this.address, required this.contactName, required this.contactPhone, this.mapLink, this.destinationLat, this.destinationLng, this.zone, this.notes, this.deliveryItemsSummary, required this.committedDate, required this.priority, required this.totalTrips, required this.counterPickupUnits, required this.status, required this.deliveries, required this.statusHistory, required this.createdAt, required this.createdByUserId, this.assignedUserId});

  int get completedTrips => deliveries.where((d) => d.result != DeliveryResult.fallido).length;

  DeliveryOrder copyWith({String? address, String? contactName, String? contactPhone, String? mapLink, double? destinationLat, double? destinationLng, String? zone, String? notes, String? deliveryItemsSummary, DateTime? committedDate, int? priority, int? totalTrips, int? counterPickupUnits, OrderStatus? status, List<DeliveryRecord>? deliveries, List<StatusHistoryItem>? statusHistory, String? assignedUserId}) => DeliveryOrder(
        id: id,
        saleId: saleId,
        customerId: customerId,
        address: address ?? this.address,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
        mapLink: mapLink ?? this.mapLink,
        destinationLat: destinationLat ?? this.destinationLat,
        destinationLng: destinationLng ?? this.destinationLng,
        zone: zone ?? this.zone,
        notes: notes ?? this.notes,
        deliveryItemsSummary: deliveryItemsSummary ?? this.deliveryItemsSummary,
        committedDate: committedDate ?? this.committedDate,
        priority: priority ?? this.priority,
        totalTrips: totalTrips ?? this.totalTrips,
        counterPickupUnits: counterPickupUnits ?? this.counterPickupUnits,
        status: status ?? this.status,
        deliveries: deliveries ?? this.deliveries,
        statusHistory: statusHistory ?? this.statusHistory,
        createdAt: createdAt,
        createdByUserId: createdByUserId,
        assignedUserId: assignedUserId ?? this.assignedUserId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'saleId': saleId,
        'customerId': customerId,
        'address': address,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'mapLink': mapLink,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'zone': zone,
        'notes': notes,
        'deliveryItemsSummary': deliveryItemsSummary,
        'committedDate': committedDate.toIso8601String(),
        'priority': priority,
        'totalTrips': totalTrips,
        'counterPickupUnits': counterPickupUnits,
        'status': enumName(status),
        'deliveries': deliveries.map((e) => e.toMap()).toList(),
        'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'createdByUserId': createdByUserId,
        'assignedUserId': assignedUserId,
      };

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) => DeliveryOrder(
        id: map['id'],
        saleId: map['saleId'],
        customerId: map['customerId'],
        address: map['address'],
        contactName: map['contactName'],
        contactPhone: map['contactPhone'],
        mapLink: map['mapLink'],
        destinationLat: (map['destinationLat'] as num?)?.toDouble(),
        destinationLng: (map['destinationLng'] as num?)?.toDouble(),
        zone: map['zone'],
        notes: map['notes'],
        deliveryItemsSummary: map['deliveryItemsSummary'],
        committedDate: DateTime.parse(map['committedDate']),
        priority: map['priority'] ?? 2,
        totalTrips: map['totalTrips'] ?? 1,
        counterPickupUnits: map['counterPickupUnits'] ?? 0,
        status: enumFromName(OrderStatus.values, map['status']),
        deliveries: (map['deliveries'] as List<dynamic>? ?? []).map((e) => DeliveryRecord.fromMap(Map<String, dynamic>.from(e))).toList(),
        statusHistory: (map['statusHistory'] as List<dynamic>? ?? []).map((e) => StatusHistoryItem.fromMap(Map<String, dynamic>.from(e))).toList(),
        createdAt: DateTime.parse(map['createdAt']),
        createdByUserId: map['createdByUserId'],
        assignedUserId: map['assignedUserId'],
      );
}

class AppData {
  final List<AppUser> users;
  final List<Customer> customers;
  final List<Sale> sales;
  final List<DeliveryOrder> orders;
  final List<Attachment> attachments;

  AppData({required this.users, required this.customers, required this.sales, required this.orders, required this.attachments});

  Map<String, dynamic> toMap() => {
        'users': users.map((e) => e.toMap()).toList(),
        'customers': customers.map((e) => e.toMap()).toList(),
        'sales': sales.map((e) => e.toMap()).toList(),
        'orders': orders.map((e) => e.toMap()).toList(),
        'attachments': attachments.map((e) => e.toMap()).toList(),
      };

  String encode() => jsonEncode(toMap());
  factory AppData.fromMap(Map<String, dynamic> map) => AppData(
        users: (map['users'] as List<dynamic>? ?? []).map((e) => AppUser.fromMap(Map<String, dynamic>.from(e))).toList(),
        customers: (map['customers'] as List<dynamic>? ?? []).map((e) => Customer.fromMap(Map<String, dynamic>.from(e))).toList(),
        sales: (map['sales'] as List<dynamic>? ?? []).map((e) => Sale.fromMap(Map<String, dynamic>.from(e))).toList(),
        orders: (map['orders'] as List<dynamic>? ?? []).map((e) => DeliveryOrder.fromMap(Map<String, dynamic>.from(e))).toList(),
        attachments: (map['attachments'] as List<dynamic>? ?? []).map((e) => Attachment.fromMap(Map<String, dynamic>.from(e))).toList(),
      );

  factory AppData.decode(String raw) => AppData.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
  factory AppData.empty() => AppData(users: [], customers: [], sales: [], orders: [], attachments: []);
}
