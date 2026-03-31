# Resumen de arquitectura

## Módulos principales
- `lib/models/models.dart`: entidades de dominio y serialización.
- `lib/services/storage_service.dart`: persistencia local offline.
- `lib/services/app_controller.dart`: reglas de negocio y estado global.
- `lib/main.dart`: UI responsive Android/Web.

## Entidades
- AppUser
- Customer
- Sale
- DeliveryOrder
- DeliveryRecord
- Attachment
- StatusHistoryItem

## Reglas ya incorporadas
- roles: admin, ventas, logistica
- estados del pedido: borrador, pendienteProgramacion, programado, enReparto, entregado, entregaParcial, entregaFallida, reprogramado, cancelado
- 1 venta puede derivar en 1 pedido con varios viajes
- las entregas registran usuario responsable

## Evolución sugerida
1. Reemplazar `StorageService` por `RemoteSyncRepository`
2. Agregar autenticación segura
3. Mover adjuntos a storage remoto
4. Incorporar geolocalización automática
5. Incorporar firma del receptor
