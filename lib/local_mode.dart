const bool kLocalOnlyMode = bool.fromEnvironment(
  'LOCAL_ONLY_MODE',
  defaultValue: false,
);

const String kLocalOnlyWriteBlockedMessage =
    'Modo local activo: escritura remota bloqueada.';
