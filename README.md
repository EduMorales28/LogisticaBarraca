# Logística Barraca MVP

Proyecto base en **Flutter** para Android y Web, pensado como MVP offline-first para gestionar:

- venta con factura PDF asociada
- pedido logístico
- entregas completas, parciales o fallidas
- evidencia con foto, observación y usuario que registró la entrega
- administración de usuarios por rol

## Estado de esta entrega

Esta entrega fue armada como **MVP funcional de demostración con persistencia local** usando `shared_preferences`.

### Qué funciona en esta versión
- Login con roles
- Alta de usuarios por administrador
- Alta de venta + pedido logístico
- Asociación de factura PDF a la venta
- Gestión de estados del pedido
- Registro de entrega con foto
- Historial básico de estados y entregas
- Interfaz responsive para Web y Android
- Operación offline local en el dispositivo/navegador

### Qué queda preparado para producción
- separación entre `models`, `controller` y `storage`
- estructura para reemplazar persistencia local por backend/Firebase
- soporte conceptual para múltiples viajes y entrega parcial

### Qué NO queda resuelto al 100% en esta entrega
- sincronización entre múltiples dispositivos
- backend remoto real
- autenticación segura productiva
- subida de archivos a storage remoto
- geolocalización automática del teléfono
- visor embebido de PDF

## Credenciales demo
- admin / admin123
- ventas / ventas123
- logistica / logistica123

## Cómo levantarlo

### Requisitos
- Flutter SDK instalado
- Android Studio o VS Code con plugin Flutter

### Pasos
1. Descomprimir el ZIP.
2. Entrar a la carpeta del proyecto.
3. Ejecutar:

```bash
flutter pub get
```

4. Correr en web:

```bash
flutter run -d chrome
```

5. Correr en Android:

```bash
flutter run -d android
```

## Publicar en Firebase Hosting (Web)

El proyecto ya queda configurado para Firebase Hosting con:

- proyecto por defecto: `logistica-barraca`
- hosting apuntando a `build/web`
- rewrite SPA de `**` a `/index.html`

### Checklist antes de deploy

1. Tener Firebase CLI instalada:

```bash
npm install -g firebase-tools
```

2. Iniciar sesión en Firebase:

```bash
firebase login
```

3. Construir la web en release:

```bash
flutter build web --release
```

4. Verificar el proyecto activo:

```bash
firebase use
```

Debe mostrar `logistica-barraca`.

5. Publicar Hosting:

```bash
firebase deploy --only hosting
```

### Importante

- No se toca Android con este deploy.
- Si usas Firebase Auth en web, asegurate de agregar el dominio de Hosting en Authorized domains dentro de Firebase Auth.

## Arquitectura recomendada para la siguiente etapa

Para pasar esto a producción, la recomendación es:
- **Flutter** para Android/Web
- **Firebase Auth + Firestore + Storage** o backend propio
- persistencia local para cache/offline
- sincronización cuando vuelva la conexión

## Notas de diseño ya incluidas
- Venta separada de Pedido
- Pedido separado de Entrega
- Un pedido puede tener varios viajes
- El retiro parcial por mostrador se modela como dato del pedido
- La ubicación puede cargarse por texto o link de Google Maps
- La ubicación de entrega final se registra de forma opcional

## Próximo paso lógico
Implementar backend real, autenticación segura, sincronización multiusuario y storage remoto de archivos.

## Flujo recomendado para GitHub y descargas APK/EXE/DMG

### 1) Preparar el repositorio local

```bash
git init
git add .
git commit -m "Inicial: Logistica Barraca MVP"
git branch -M main
```

### 2) Crear repositorio nuevo en GitHub

- Crear un repositorio vacío en tu cuenta, sin README inicial.
- Copiar la URL HTTPS o SSH del repo nuevo.

```bash
git remote add origin <URL_DEL_REPO>
git push -u origin main
```

### 3) Build automático de artefactos

Este proyecto incluye el workflow:

- `.github/workflows/release-builds.yml`

Ese workflow compila:

- Android APK release
- Windows EXE empaquetado en ZIP
- macOS app empaquetada como DMG

Opciones de ejecución:

- Manual: GitHub > Actions > Build Release Artifacts > Run workflow
- Por tag: al subir un tag `v*` (ejemplo `v0.1.1`)

### 4) Descargar artefactos

- En una ejecución manual: pestaña Actions > run > Artifacts
- En un release por tag: pestaña Releases con archivos adjuntos

### 5) Publicar una versión descargable

```bash
git tag v0.1.1
git push origin v0.1.1
```

Con eso, GitHub compila y publica automáticamente:

- `app-release.apk`
- `logistica_barraca_windows_release.zip`
- `logistica_barraca_mvp.dmg`

## Validación local rápida de build

En macOS se pudo validar:

```bash
flutter build apk --release
flutter build macos --release
```

Resultado esperado:

- APK en `build/app/outputs/flutter-apk/app-release.apk`
- App macOS en `build/macos/Build/Products/Release/logistica_barraca_mvp.app`

Nota:

- El EXE de Windows se genera en CI sobre `windows-latest`, porque `flutter build windows` solo funciona en host Windows.
