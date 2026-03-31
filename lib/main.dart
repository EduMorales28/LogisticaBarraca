import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'screens/dispatch_planning_page.dart';
import 'authz.dart';
import 'firebase_options.dart';
import 'screens/delivered_page.dart';
import 'screens/orders_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const BarracaApp());
}

class BarracaApp extends StatelessWidget {
  const BarracaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logística Barraca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006F5B),
          brightness: Brightness.light,
          primary: const Color(0xFF006F5B),
          secondary: const Color(0xFF0A6C80),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F1EC),
        cardTheme: CardThemeData(
          margin: const EdgeInsets.all(8),
          color: const Color(0xFFF7EFE6),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF3F3F44),
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFB3BA74).withOpacity(0.28),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(
              color: Color(0xFF3F3F44),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Colors.white,
          selectedIconTheme: IconThemeData(color: Color(0xFF006F5B)),
          selectedLabelTextStyle: TextStyle(
            color: Color(0xFF006F5B),
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme: IconThemeData(color: Color(0xFF66666A)),
          unselectedLabelTextStyle: TextStyle(
            color: Color(0xFF66666A),
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: Color(0xFFB3BA74),
          useIndicator: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF006F5B), width: 1.6),
          ),
          labelStyle: const TextStyle(color: Color(0xFF66666A)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF006F5B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF006F5B),
            side: const BorderSide(color: Color(0xFF006F5B)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xFF3F3F44),
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF3F3F44),
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: Color(0xFF4D4D52)),
          bodyMedium: TextStyle(color: Color(0xFF66666A)),
        ),
      ),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginPage();
        }
        return const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'lablap2015@gmail.com');
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      final uid = credential.user!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception('No existe perfil del usuario en Firestore.');
      }

      final data = userDoc.data()!;
      final activoRaw = data['activo'];
      final activo = activoRaw == true || activoRaw.toString().toLowerCase() == 'true';

      if (!activo) {
        await FirebaseAuth.instance.signOut();
        throw Exception('El usuario está inactivo.');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Error de autenticación.';
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Logística Barraca',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: Text(_loading ? 'Ingresando...' : 'Ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error cargando usuario: ${snapshot.error}')),
          );
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo_barraca_morales.png',
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Logística Barraca',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No existe perfil del usuario en Firestore.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          );
        }

        final activoRaw = data['activo'];
        final profile = AppUserProfile(
          uid: authUser.uid,
          email: authUser.email ?? '',
          fullName: (data['fullName'] ??
                  data['fullname'] ??
                  data['nombre'] ??
                  authUser.email ??
                  '')
              .toString(),
          role: parseAppRole(data['role'] ?? data['rol']),
          active: activoRaw == true || activoRaw.toString().toLowerCase() == 'true',
        );

        if (!profile.active) {
          Future.microtask(() => FirebaseAuth.instance.signOut());
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final entries = _buildEntries(profile);
        if (index >= entries.length) {
          index = 0;
        }

        return CurrentAppUserScope(
          profile: profile,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Logística Barraca'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      '${profile.fullName} · ${appRoleLabel(profile.role)}',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Row(
              children: [
                if (MediaQuery.of(context).size.width > 900)
                  NavigationRail(
                    selectedIndex: index,
                    labelType: NavigationRailLabelType.all,
                    destinations: entries
                        .map(
                          (e) => NavigationRailDestination(
                            icon: e.destination.icon,
                            label: Text(e.destination.label),
                          ),
                        )
                        .toList(),
                    onDestinationSelected: (i) => setState(() => index = i),
                  ),
                Expanded(child: entries[index].page),
              ],
            ),
            bottomNavigationBar: MediaQuery.of(context).size.width <= 900
                ? NavigationBar(
                    selectedIndex: index,
                    destinations:
                        entries.map((e) => e.destination).toList(),
                    onDestinationSelected: (i) => setState(() => index = i),
                  )
                : null,
          ),
        );
      },
    );
  }

  List<_NavEntry> _buildEntries(AppUserProfile profile) {
    final items = <_NavEntry>[];

    if (profile.canSeeDashboard) {
      items.add(
        const _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Resumen',
          ),
          page: DashboardPage(),
        ),
      );
    }

    if (profile.canSeePending) {
  items.add(
    _NavEntry(
      destination: const NavigationDestination(
        icon: Icon(Icons.local_shipping_outlined),
        label: 'Pendientes',
      ),
      page: OrdersPage(profile: profile),
    ),
  );
}

if (profile.role == AppRole.admin ||
    profile.role == AppRole.encargadoLogistica) {
  items.add(
    _NavEntry(
      destination: const NavigationDestination(
        icon: Icon(Icons.reorder),
        label: 'Programación',
      ),
      page: const DispatchPlanningPage(),
    ),
  );
}

    if (profile.canSeeDelivered) {
      items.add(
        const _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.task_alt),
            label: 'Entregados',
          ),
          page: DeliveredFirestorePage(),
        ),
      );
    }

    if (profile.canCreateOrders) {
      items.add(
        const _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Nuevo pedido',
          ),
          page: NewOrderPage(),
        ),
      );
    }

    if (profile.canManageUsers) {
      items.add(
        const _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Usuarios',
          ),
          page: UsersPage(),
        ),
      );
    }

    return items;
  }
}

class _NavEntry {
  final NavigationDestination destination;
  final Widget page;

  const _NavEntry({
    required this.destination,
    required this.page,
  });
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  bool _isPending(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? '').toString();
    final progress = (data['deliveryProgress'] ?? 'sin_entregar').toString();
    return estado == 'pendiente_programacion' ||
        estado == 'entrega_parcial' ||
        progress == 'parcial';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pendientes = docs
            .where((d) => _isPending(d.data() as Map<String, dynamic>))
            .length;
        final entregados = docs.where((d) => d['estado'] == 'entregado').length;
        final parciales = docs
            .where((d) =>
                (d['deliveryProgress'] ?? '').toString() == 'parcial' ||
                (d['estado'] ?? '').toString() == 'entrega_parcial')
            .length;
        final fallidos =
            docs.where((d) => d['estado'] == 'entrega_fallida').length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Pedidos totales',
                  value: '$total',
                  icon: Icons.inventory_2_outlined,
                ),
                _MetricCard(
                  label: 'Pendientes',
                  value: '$pendientes',
                  icon: Icons.pending_actions,
                ),
                _MetricCard(
                  label: 'Entregados',
                  value: '$entregados',
                  icon: Icons.task_alt,
                ),
                _MetricCard(
                  label: 'Parciales',
                  value: '$parciales',
                  icon: Icons.rule_folder_outlined,
                ),
                _MetricCard(
                  label: 'Fallidos',
                  value: '$fallidos',
                  icon: Icons.error_outline,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewOrderPage extends StatefulWidget {
  const NewOrderPage({super.key});

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  final uuid = const Uuid();
  final _invoice = TextEditingController();
  final _customer = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _mapLink = TextEditingController();
  final _zone = TextEditingController();
  final _notes = TextEditingController();
  final _date = TextEditingController(
    text: DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.now().add(const Duration(days: 1)),
    ),
  );
  final _trips = TextEditingController(text: '1');
  final _pickupUnits = TextEditingController(text: '0');
  final _pickupSummary = TextEditingController();
  final _deliverySummary = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  int priority = 2;
  List<Uint8List> pdfFilesBytes = [];
  List<String> pdfFileNames = [];
  List<Uint8List> invoicePhotoBytes = [];
  List<String> invoicePhotoNames = [];
  bool saving = false;

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null) return;

    final selected = result.files.where((f) => f.bytes != null).toList();
    if (selected.isEmpty) return;

    setState(() {
      pdfFilesBytes = selected.map((f) => f.bytes!).toList();
      pdfFileNames = selected.map((f) => f.name).toList();
    });
  }

  Future<void> pickInvoicePhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null) return;

    final selected = result.files.where((f) => f.bytes != null).toList();
    if (selected.isEmpty) return;

    setState(() {
      invoicePhotoBytes = selected.map((f) => f.bytes!).toList();
      invoicePhotoNames = selected.map((f) => f.name).toList();
    });
  }

  void _fillMapsLinkFromAddress() {
    final address = _address.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribí primero la dirección del destino.'),
        ),
      );
      return;
    }

    _mapLink.text = _mapsUrlForQuery(address);
    _launch(_mapLink.text);
    setState(() {});
  }

  void _fillMapsLinkFromCoords() {
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordenadas inválidas.')),
      );
      return;
    }

    _mapLink.text = _mapsUrlForCoords(lat, lng);
    _launch(_mapLink.text);
    setState(() {});
  }

  Future<void> _saveOrder() async {
    if (_invoice.text.trim().isEmpty ||
        _customer.text.trim().isEmpty ||
        _contact.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos obligatorios')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      String? pdfUrl;
      final List<String> invoicePdfUrls = [];
      final List<String> pendingLocalPdfNames = [];

      for (int i = 0; i < pdfFilesBytes.length; i++) {
        final bytes = pdfFilesBytes[i];
        final name = pdfFileNames[i];

        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('orders_pdfs')
              .child('${DateTime.now().millisecondsSinceEpoch}_${i}_$name');

          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'application/pdf'),
          );

          final url = await storageRef.getDownloadURL();
          invoicePdfUrls.add(url);
        } catch (_) {
          pendingLocalPdfNames.add(name);
        }
      }

      if (invoicePdfUrls.isNotEmpty) {
        pdfUrl = invoicePdfUrls.first;
      }

      final List<String> invoicePhotoUrls = [];
      final List<String> pendingLocalInvoicePhotoNames = [];
      for (int i = 0; i < invoicePhotoBytes.length; i++) {
        final bytes = invoicePhotoBytes[i];
        final name = invoicePhotoNames[i];
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('orders_invoice_photos')
              .child('${DateTime.now().millisecondsSinceEpoch}_${i}_$name');

          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          final url = await storageRef.getDownloadURL();
          invoicePhotoUrls.add(url);
        } catch (_) {
          pendingLocalInvoicePhotoNames.add(name);
        }
      }

      final hasPendingLocalUploads =
          pendingLocalPdfNames.isNotEmpty || pendingLocalInvoicePhotoNames.isNotEmpty;

      await FirebaseFirestore.instance.collection('orders').add({
        'pdfUrl': pdfUrl,
        'invoicePdfUrls': invoicePdfUrls.isEmpty ? null : invoicePdfUrls,
        'invoicePhotoUrls': invoicePhotoUrls.isEmpty ? null : invoicePhotoUrls,
        'pendingLocalPdfNames':
            pendingLocalPdfNames.isEmpty ? null : pendingLocalPdfNames,
        'pendingLocalInvoicePhotoNames': pendingLocalInvoicePhotoNames.isEmpty
            ? null
            : pendingLocalInvoicePhotoNames,
        'hasPendingLocalUploads': hasPendingLocalUploads,
        'clienteNombreSnapshot': _customer.text.trim(),
        'direccionTexto': _address.text.trim(),
        'estado': 'pendiente_programacion',
        'deliveryProgress': 'sin_entregar',
        'prioridad': priority == 1
            ? 'alta'
            : priority == 2
                ? 'media'
                : 'baja',
        'observaciones': _notes.text.trim().isEmpty ? '' : _notes.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'invoiceNumber': _invoice.text.trim(),
        'contactName': _contact.text.trim(),
        'contactPhone': _phone.text.trim(),
        'committedDate':
            DateFormat('yyyy-MM-dd HH:mm').parse(_date.text.trim()),
        'mapLink': _mapLink.text.trim().isEmpty ? null : _mapLink.text.trim(),
        'destinationLat': double.tryParse(_lat.text.replaceAll(',', '.')),
        'destinationLng': double.tryParse(_lng.text.replaceAll(',', '.')),
        'zone': _zone.text.trim().isEmpty ? null : _zone.text.trim(),
        'pickupSummary': _pickupSummary.text.trim().isEmpty
            ? null
            : _pickupSummary.text.trim(),
        'deliverySummary': _deliverySummary.text.trim().isEmpty
            ? null
            : _deliverySummary.text.trim(),
        'itemsSummary': _deliverySummary.text.trim().isEmpty
            ? null
            : _deliverySummary.text.trim(),
        'totalTrips': int.tryParse(_trips.text.trim()) ?? 1,
        'counterPickupUnits': int.tryParse(_pickupUnits.text.trim()) ?? 0,
        'createdByUid': FirebaseAuth.instance.currentUser?.uid,
        'localTempId': uuid.v4(),
      });

      if (!mounted) return;

      final msg = hasPendingLocalUploads
          ? 'Pedido guardado localmente. Quedaron adjuntos pendientes de subir.'
          : 'Pedido creado correctamente';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      _invoice.clear();
      _customer.clear();
      _contact.clear();
      _phone.clear();
      _address.clear();
      _mapLink.clear();
      _zone.clear();
      _notes.clear();
      _lat.clear();
      _lng.clear();
      _pickupSummary.clear();
      _deliverySummary.clear();
      _date.text = DateFormat('yyyy-MM-dd HH:mm').format(
        DateTime.now().add(const Duration(days: 1)),
      );
      _trips.text = '1';
      _pickupUnits.text = '0';
      priority = 2;
      pdfFilesBytes = [];
      pdfFileNames = [];
      invoicePhotoBytes = [];
      invoicePhotoNames = [];

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    _invoice.dispose();
    _customer.dispose();
    _contact.dispose();
    _phone.dispose();
    _address.dispose();
    _mapLink.dispose();
    _zone.dispose();
    _notes.dispose();
    _date.dispose();
    _trips.dispose();
    _pickupUnits.dispose();
    _pickupSummary.dispose();
    _deliverySummary.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = CurrentAppUserScope.of(context);
    if (!profile.canCreateOrders) {
      return const AccessDeniedCard(
        title: 'Nuevo pedido',
        message: 'Tu usuario no tiene permiso para crear pedidos.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nueva venta + pedido',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(
                      width: 240,
                      child: TextField(
                        controller: _invoice,
                        decoration: const InputDecoration(
                          labelText: 'N° factura / venta *',
                        ),
                      ),
                    ),
                    _field(
                      width: 300,
                      child: TextField(
                        controller: _customer,
                        decoration: const InputDecoration(labelText: 'Cliente *'),
                      ),
                    ),
                    _field(
                      width: 240,
                      child: TextField(
                        controller: _contact,
                        decoration: const InputDecoration(labelText: 'Contacto *'),
                      ),
                    ),
                    _field(
                      width: 220,
                      child: TextField(
                        controller: _phone,
                        decoration: const InputDecoration(labelText: 'Teléfono *'),
                      ),
                    ),
                    _field(
                      width: 500,
                      child: TextField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'Dirección *'),
                      ),
                    ),
                    _field(
                      width: 220,
                      child: TextField(
                        controller: _zone,
                        decoration: const InputDecoration(labelText: 'Zona'),
                      ),
                    ),
                    _field(
                      width: 220,
                      child: TextField(
                        controller: _date,
                        decoration: const InputDecoration(
                          labelText: 'Fecha compromiso yyyy-MM-dd HH:mm *',
                        ),
                      ),
                    ),
                    _field(
                      width: 150,
                      child: TextField(
                        controller: _trips,
                        decoration: const InputDecoration(labelText: 'Viajes totales'),
                      ),
                    ),
                    _field(
                      width: 200,
                      child: TextField(
                        controller: _pickupUnits,
                        decoration: const InputDecoration(
                          labelText: 'Retiro mostrador (unidades)',
                        ),
                      ),
                    ),
                    _field(
                      width: 200,
                      child: DropdownButtonFormField<int>(
                        value: priority,
                        decoration:
                            const InputDecoration(labelText: 'Prioridad'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Alta')),
                          DropdownMenuItem(value: 2, child: Text('2 Media')),
                          DropdownMenuItem(value: 3, child: Text('3 Baja')),
                        ],
                        onChanged: (v) => setState(() => priority = v ?? 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Destino guiado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 500,
                      child: TextField(
                        controller: _mapLink,
                        decoration: const InputDecoration(
                          labelText: 'Link Google Maps del destino',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _lat,
                        decoration:
                            const InputDecoration(labelText: 'Latitud'),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _lng,
                        decoration:
                            const InputDecoration(labelText: 'Longitud'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _fillMapsLinkFromAddress,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Elegir destino en Google Maps'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _fillMapsLinkFromCoords,
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Generar desde coordenadas'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pickupSummary,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Retiro por mostrador',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliverySummary,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Pendiente para logística',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Adjuntar factura PDF'),
                    ),
                    Text(
                      pdfFileNames.isEmpty
                          ? 'Sin PDF todavía'
                          : '${pdfFileNames.length} PDF(s) seleccionado(s)',
                    ),
                  ],
                ),
                if (pdfFileNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...pdfFileNames.map((name) => Text('• $name')),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pickInvoicePhotos,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Adjuntar fotos de factura'),
                    ),
                    Text(invoicePhotoNames.isEmpty
                        ? 'Sin fotos todavía'
                        : '${invoicePhotoNames.length} foto(s) seleccionada(s)'),
                  ],
                ),
                if (invoicePhotoNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...invoicePhotoNames.map((name) => Text('• $name')),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : _saveOrder,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Guardando...' : 'Guardar venta y pedido'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = CurrentAppUserScope.of(context);
    if (!profile.canManageUsers) {
      return const AccessDeniedCard(
        title: 'Usuarios',
        message: 'Tu usuario no tiene permiso para administrar usuarios.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('fullName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Usuarios y permisos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desde aquí podés activar o desactivar usuarios y asignarles el rol operativo. '
              'La creación de usuarios nuevos conviene hacerla desde Firebase Authentication '
              'o con una función administrativa aparte.',
            ),
            const SizedBox(height: 12),
            ...docs.map(
              (doc) {
                final data = doc.data();
                final role = parseAppRole(data['role'] ?? data['rol']);
                final activoRaw = data['activo'];
                final active = activoRaw == true ||
                    activoRaw.toString().toLowerCase() == 'true';
                final name = (data['fullName'] ??
                        data['fullname'] ??
                        data['nombre'] ??
                        'Sin nombre')
                    .toString();
                final email = (data['email'] ?? '').toString();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (email.isNotEmpty) Text(email),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<AppRole>(
                                value: role,
                                decoration:
                                    const InputDecoration(labelText: 'Rol'),
                                items: AppRole.values
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(appRoleLabel(r)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  await doc.reference.update({'role': value.name});
                                },
                              ),
                            ),
                            FilterChip(
                              selected: active,
                              label: Text(active ? 'Activo' : 'Inactivo'),
                              onSelected: (_) async {
                                await doc.reference.update({'activo': !active});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_roleToolsDescription(role)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

String _roleToolsDescription(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return 'Herramientas: resumen, pendientes, entregados, nuevo pedido, gestión de usuarios y cierre de entregas.';
    case AppRole.ventas:
      return 'Herramientas: resumen, pendientes, entregados y nuevo pedido. No puede cerrar entregas ni gestionar usuarios.';
    case AppRole.logistica:
      return 'Herramientas: resumen, pendientes, entregados y cierre de entregas con foto y ubicación. No puede crear pedidos.';
    case AppRole.consulta:
      return 'Herramientas: solo lectura en resumen, pendientes y entregados. No puede crear pedidos ni cerrar entregas.';
      case AppRole.encargadoLogistica:
  return 'Herramientas: programación logística, reorden de despacho y control de entregas. No crea pedidos.';
  }
}

class AccessDeniedCard extends StatelessWidget {
  final String title;
  final String message;

  const AccessDeniedCard({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _mapsUrlForQuery(String query) {
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
}

String _mapsUrlForCoords(double lat, double lng) {
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}

Future<void> _launch(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
