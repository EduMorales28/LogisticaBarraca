# Logística Barraca - última versión incremental

Este paquete contiene archivos de reemplazo para aplicar sobre tu proyecto actual, sin rehacer la arquitectura completa.

## Archivos incluidos
- `lib/main.dart`
- `lib/authz.dart`
- `lib/firebase_options.dart`
- `lib/screens/orders_page.dart`
- `lib/screens/delivered_page.dart`
- `lib/screens/dispatch_planning_page.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
- `android/app/google-services.json`
- `CHANGELOG_CORTO.md`

## Cambios implementados
1. Numeración diaria automática de pedido con transacción Firestore:
   - `order_counters/{yyyy-MM-dd}`
   - `orders.orderNumber`
   - `orders.dailySequence`
   - `orders.sequenceDateKey`
2. Nuevo rol `encargado_logistica`.
3. Nueva pantalla de programación logística con reordenamiento y guardado de `dispatchOrder`.
4. Formulario de nuevo pedido simplificado:
   - se elimina `zona`
   - se elimina `pendiente para logística`
   - se conserva compatibilidad de lectura con documentos viejos
5. Trazabilidad mejorada:
   - subcolección `orders/{orderId}/delivery_events`
   - múltiples fotos por evento
   - ubicación, observaciones, recibido por y timestamp por cada evento
   - entregas parciales permanecen en pendientes
6. Pendientes / Entregados / Detalle:
   - muestran `orderNumber`
   - parciales previas visibles
   - entregados ya no mezcla pedidos parcialmente entregados que siguen activos
7. Android:
   - permisos de ubicación agregados en `AndroidManifest.xml`

## Pasos manuales
### Firebase Authentication / users
Crear el usuario del nuevo rol y en `users/{uid}` guardar:
```json
{
  "role": "encargado_logistica",
  "activo": true
}
```

### Firestore rules
Asegurar que:
- `encargado_logistica` pueda actualizar `dispatchOrder`
- logística/admin puedan crear `delivery_events`
- los pedidos sigan pudiéndose leer aunque no tengan campos nuevos

### Firestore indexes
Si la consola de Firebase pide índices para consultas combinadas, crearlos desde el link que te muestra el error.

## Nota honesta
La validación final de captura GPS en un Android físico no quedó cerrada durante esta conversación porque no fue posible completar la conexión ADB del teléfono. El código y los permisos Android quedaron preparados para esa prueba posterior.
