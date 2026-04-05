import 'package:flutter/material.dart';

enum AppRole { admin, ventas, logistica, encargadoLogistica, consulta }

AppRole parseAppRole(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();
  switch (raw) {
    case 'admin':
    case 'administrador':
      return AppRole.admin;
    case 'ventas':
    case 'mostrador':
      return AppRole.ventas;
    case 'logistica':
    case 'logística':
      return AppRole.logistica;
    case 'encargado_logistica':
    case 'encargado logística':
    case 'encargado logistica':
    case 'programacion_logistica':
    case 'programación logística':
      return AppRole.encargadoLogistica;
    case 'consulta':
    case 'viewer':
    case 'lectura':
      return AppRole.consulta;
    default:
      return AppRole.consulta;
  }
}

String appRoleStorageValue(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return 'admin';
    case AppRole.ventas:
      return 'ventas';
    case AppRole.logistica:
      return 'logistica';
    case AppRole.encargadoLogistica:
      return 'encargado_logistica';
    case AppRole.consulta:
      return 'consulta';
  }
}

String appRoleLabel(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return 'Administrador';
    case AppRole.ventas:
      return 'Ventas';
    case AppRole.logistica:
      return 'Logística';
    case AppRole.encargadoLogistica:
      return 'Encargado logística';
    case AppRole.consulta:
      return 'Consulta';
  }
}

class AppUserProfile {
  final String uid;
  final String email;
  final String fullName;
  final AppRole role;
  final bool active;

  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.active,
  });

  String get displayName => fullName;
  bool get isAdmin => role == AppRole.admin;
  bool get canCreateOrders => role == AppRole.admin || role == AppRole.ventas;
  bool get canManageUsers => role == AppRole.admin;
  bool get canCloseDelivery => role == AppRole.admin || role == AppRole.logistica;
  bool get canCloseDeliveries => canCloseDelivery;
  bool get canManageDispatch => role == AppRole.admin || role == AppRole.encargadoLogistica;
  bool get canSeeDispatchPlanning => canManageDispatch;
  bool get canDeleteOrders => role == AppRole.admin;
  bool get canDeleteDeliveryEvents => role == AppRole.admin;
  bool get canAddAdminEvidence => role == AppRole.admin;
  bool get canReceiveOrderNotifications =>
      role == AppRole.logistica || role == AppRole.encargadoLogistica;
  bool get canSeeDashboard => true;
  bool get canSeePending => true;
  bool get canSeeDelivered => true;
}

class CurrentAppUserScope extends InheritedWidget {
  final AppUserProfile profile;

  const CurrentAppUserScope({
    super.key,
    required this.profile,
    required super.child,
  });

  static AppUserProfile of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CurrentAppUserScope>();
    assert(scope != null, 'CurrentAppUserScope no encontrado en el árbol');
    return scope!.profile;
  }

  @override
  bool updateShouldNotify(CurrentAppUserScope oldWidget) {
    return oldWidget.profile.uid != profile.uid ||
        oldWidget.profile.role != profile.role ||
        oldWidget.profile.active != profile.active ||
        oldWidget.profile.fullName != profile.fullName ||
        oldWidget.profile.email != profile.email;
  }
}
