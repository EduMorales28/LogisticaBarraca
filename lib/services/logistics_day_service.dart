import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../authz.dart';

class LogisticsTruckOption {
  final String id;
  final String label;

  const LogisticsTruckOption({required this.id, required this.label});
}

const List<LogisticsTruckOption> logisticsTruckOptions = [
  LogisticsTruckOption(id: 'volkswagen', label: 'Volkswagen'),
  LogisticsTruckOption(id: 'aeolus_oab_7694', label: 'Aeolus - OAB 7694'),
  LogisticsTruckOption(id: 'jmc_oab_4479', label: 'JMC - OAB 4479'),
];

bool requiresAndroidLogisticsDayControl(AppUserProfile profile) {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      profile.role == AppRole.logistica;
}

String logisticsPlatformLabel() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

String logisticsDayDateKey([DateTime? date]) {
  final current = (date ?? DateTime.now()).toLocal();
  return DateFormat('yyyy-MM-dd').format(current);
}

bool isOpenLogisticsDay(Map<String, dynamic>? data) {
  if (data == null) return false;
  final status = (data['status'] ?? 'open').toString();
  return status == 'open' && data['finalKm'] == null;
}