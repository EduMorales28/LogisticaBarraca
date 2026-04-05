import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'screens/dispatch_planning_page.dart';
import 'authz.dart';
import 'core/invoice_parser.dart';
import 'firebase_options.dart';
import 'local_mode.dart';
import 'screens/delivered_page.dart';
import 'screens/orders_page.dart';
import 'screens/reports_page.dart';
import 'services/notification_service.dart';
import 'services/logistics_day_service.dart';
import 'widgets/google_maps_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  if (kLocalOnlyMode) {
    // Intentar auth anónima (web). Si falla (Android con anon auth deshabilitado),
    // usar Firestore completamente offline con caché local.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {
      await FirebaseFirestore.instance.disableNetwork();
    }
  }
  await NotificationService.init();
  runApp(const BarracaApp());
}

class BarracaApp extends StatelessWidget {
  const BarracaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logística Barraca',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'UY'),
      supportedLocales: const [
        Locale('es', 'UY'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006341),
          brightness: Brightness.light,
          primary: const Color(0xFF006341),
          onPrimary: Colors.white,
          secondary: const Color(0xFF1B617C),
          onSecondary: Colors.white,
          tertiary: const Color(0xFF898D4A),
          surface: Colors.white,
          onSurface: const Color(0xFF1C1C1E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4F2),
        cardTheme: CardThemeData(
          margin: const EdgeInsets.all(8),
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF006341).withOpacity(0.10)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006341),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF006341).withOpacity(0.15),
          iconTheme: const WidgetStatePropertyAll(
            IconThemeData(color: Color(0xFF5E5E5E)),
          ),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(
              color: Color(0xFF3F3F44),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.white,
          selectedIconTheme: const IconThemeData(color: Color(0xFF006341)),
          selectedLabelTextStyle: const TextStyle(
            color: Color(0xFF006341),
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme: IconThemeData(color: const Color(0xFF006341).withOpacity(0.45)),
          unselectedLabelTextStyle: TextStyle(
            color: const Color(0xFF006341).withOpacity(0.55),
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: const Color(0xFF006341).withOpacity(0.14),
          useIndicator: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAF9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF006341).withOpacity(0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF006341).withOpacity(0.20)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF006341), width: 1.8),
          ),
          labelStyle: const TextStyle(color: Color(0xFF5E5E5E)),
          floatingLabelStyle: const TextStyle(color: Color(0xFF006341), fontWeight: FontWeight.w600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF006341),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF006341),
            side: const BorderSide(color: Color(0xFF006341), width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF006341),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF006341).withOpacity(0.08),
          selectedColor: const Color(0xFF006341).withOpacity(0.20),
          labelStyle: const TextStyle(color: Color(0xFF006341), fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        dividerTheme: DividerThemeData(
          color: const Color(0xFF006341).withOpacity(0.12),
          thickness: 1,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xFF006341),
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: Color(0xFF2D2D30)),
          bodyMedium: TextStyle(color: Color(0xFF5E5E5E)),
          labelSmall: TextStyle(color: Color(0xFF7E7E7E)),
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
    if (kLocalOnlyMode) {
      return const HomePage();
    }

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF004D30),
              Color(0xFF006341),
              Color(0xFF1B617C),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/images/logo_barraca_morales_transparent.png',
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sistema de logística',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Card del formulario
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF006341),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _loading ? null : _signIn,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _loading ? 'Ingresando...' : 'Ingresar',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Aclaración de versión
                  Text(
                    'Barraca Morales · v0.1',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
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
  AppRole _localRole = AppRole.admin;

  // Listener de nuevos pedidos
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;
  final Set<String> _knownOrderIds = {};
  bool _initialLoadDone = false;
  String? _notificationListenerKey;

  @override
  void initState() {
    super.initState();
  }

  void _listenForNewOrders() {
    _ordersSubscription?.cancel();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      if (!_initialLoadDone) {
        // Primera carga: solo registrar IDs existentes sin notificar
        for (final doc in snapshot.docs) {
          _knownOrderIds.add(doc.id);
        }
        _initialLoadDone = true;
        return;
      }
      // Cargas siguientes: detectar IDs nuevos
      for (final doc in snapshot.docs) {
        if (!_knownOrderIds.contains(doc.id)) {
          _knownOrderIds.add(doc.id);
          final data = doc.data();
          final orderNumber = (data['invoiceNumber'] ?? data['orderNumber'] ?? doc.id).toString();
          final customer = (data['clienteNombreSnapshot'] ?? '').toString();
          NotificationService.showNewOrderNotification(
            orderNumber: orderNumber,
            customerName: customer,
          );
        }
      }
    });
  }

  void _stopOrderNotifications() {
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _notificationListenerKey = null;
    _knownOrderIds.clear();
    _initialLoadDone = false;
  }

  void _syncOrderNotifications(AppUserProfile profile) {
    if (!profile.canReceiveOrderNotifications) {
      _stopOrderNotifications();
      return;
    }

    final nextKey = '${profile.uid}:${profile.role.name}';
    if (_notificationListenerKey == nextKey && _ordersSubscription != null) {
      return;
    }

    _notificationListenerKey = nextKey;
    _knownOrderIds.clear();
    _initialLoadDone = false;
    _listenForNewOrders();
  }

  AppUserProfile _localProfile(User? authUser) {
    final email = authUser?.email ?? 'local@offline.test';
    final names = {
      AppRole.admin: 'Admin (local)',
      AppRole.ventas: 'Ventas (local)',
      AppRole.logistica: 'Logística (local)',
      AppRole.encargadoLogistica: 'Enc. Logística (local)',
      AppRole.consulta: 'Consulta (local)',
    };
    return AppUserProfile(
      uid: authUser?.uid ?? 'local-offline-user',
      email: email,
      fullName: names[_localRole] ?? 'Modo local offline',
      role: _localRole,
      active: true,
    );
  }

  Widget _buildScaffold(AppUserProfile profile) {
    _syncOrderNotifications(profile);

    final entries = _buildEntries(profile);
    final requiresDayControl = requiresAndroidLogisticsDayControl(profile);
    if (index >= entries.length) {
      index = 0;
    }

    final navigationBody = Row(
      children: [
        if (MediaQuery.of(context).size.width > 900)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006341).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
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
          ),
        Expanded(child: entries[index].page),
      ],
    );

    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo_m_icon.png',
                height: 28,
                color: Colors.white,
                colorBlendMode: BlendMode.srcATop,
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Logística Barraca',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (kLocalOnlyMode) ...[
              PopupMenuButton<AppRole>(
                tooltip: 'Cambiar rol',
                icon: const Icon(Icons.switch_account),
                initialValue: _localRole,
                onSelected: (v) => setState(() {
                  _localRole = v;
                  index = 0;
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: AppRole.admin, child: Text('Admin')),
                  PopupMenuItem(value: AppRole.ventas, child: Text('Ventas')),
                  PopupMenuItem(value: AppRole.logistica, child: Text('Logística')),
                  PopupMenuItem(value: AppRole.encargadoLogistica, child: Text('Enc. Logística')),
                  PopupMenuItem(value: AppRole.consulta, child: Text('Consulta')),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                if (!kLocalOnlyMode) {
                  await FirebaseAuth.instance.signOut();
                }
              },
              icon: const Icon(Icons.logout),
              tooltip: 'Salir',
            ),
          ],
        ),
        body: requiresDayControl
          ? LogisticsDayShell(profile: profile, child: navigationBody)
          : navigationBody,
        bottomNavigationBar: MediaQuery.of(context).size.width <= 900
            ? Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006341).withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: index,
                  destinations: entries.map((e) => e.destination).toList(),
                  onDestinationSelected: (i) => setState(() => index = i),
                ),
              )
            : null,
      );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (kLocalOnlyMode) {
      return _buildScaffold(_localProfile(authUser));
    }

    if (authUser == null) {
      _stopOrderNotifications();
      return const LoginPage();
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
          return _buildScaffold(_localProfile(authUser));
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
          _stopOrderNotifications();
          Future.microtask(() => FirebaseAuth.instance.signOut());
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return _buildScaffold(profile);
      },
    );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
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
        label: 'Program.',
      ),
      page: DispatchPlanningPage(profile: profile),
    ),
  );
}

    if (profile.canSeeDelivered) {
      items.add(
        _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.task_alt),
            label: 'Entregados',
          ),
          page: DeliveredFirestorePage(profile: profile),
        ),
      );
    }

    if (profile.isAdmin) {
      items.add(
        _NavEntry(
          destination: const NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            label: 'Reportes',
          ),
          page: ReportsPage(profile: profile),
        ),
      );
    }

    if (profile.canCreateOrders) {
      items.add(
        _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Nuevo',
          ),
          page: NewOrderPage(profile: profile),
        ),
      );
    }

    if (profile.canManageUsers) {
      items.add(
        _NavEntry(
          destination: NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Usuarios',
          ),
          page: UsersPage(profile: profile),
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

class LogisticsDayShell extends StatelessWidget {
  final AppUserProfile profile;
  final Widget child;

  const LogisticsDayShell({super.key, required this.profile, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('logistics_day_logs')
          .where('userUid', isEqualTo: profile.uid)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo cargar la jornada de logística: ${snapshot.error}'),
                ),
              ),
            ),
          );
        }

        final openDoc = snapshot.data?.docs.isNotEmpty == true
            ? snapshot.data!.docs.first
            : null;
        final openData = openDoc?.data();

        if (openData == null) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: LogisticsDayStartCard(profile: profile),
            ),
          );
        }

        return Column(
          children: [
            LogisticsDayActiveCard(
              profile: profile,
              dayRef: openDoc!.reference,
              data: openData,
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class LogisticsDayStartCard extends StatefulWidget {
  final AppUserProfile profile;

  const LogisticsDayStartCard({super.key, required this.profile});

  @override
  State<LogisticsDayStartCard> createState() => _LogisticsDayStartCardState();
}

class _LogisticsDayStartCardState extends State<LogisticsDayStartCard> {
  final _initialKm = TextEditingController();
  final _openedByName = TextEditingController();
  String _truckId = logisticsTruckOptions.first.id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openedByName.text = widget.profile.fullName;
  }

  LogisticsTruckOption get _selectedTruck =>
      logisticsTruckOptions.firstWhere((truck) => truck.id == _truckId);

  Future<void> _startDay() async {
    final openedByName = _openedByName.text.trim();
    if (openedByName.isEmpty) {
      _toast('Ingresá el nombre de quien abre el camión.');
      return;
    }

    final initialKm = int.tryParse(_initialKm.text.trim());
    if (initialKm == null || initialKm < 0) {
      _toast('Ingresá un kilometraje inicial válido.');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toLocal();
      final existingOpen = await FirebaseFirestore.instance
          .collection('logistics_day_logs')
          .where('userUid', isEqualTo: widget.profile.uid)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();
      if (existingOpen.docs.isNotEmpty) {
        _toast('Ya hay un camión abierto. Cerralo antes de iniciar otro.');
        return;
      }

      await FirebaseFirestore.instance.collection('logistics_day_logs').add({
        'dateKey': logisticsDayDateKey(now),
        'dateValue': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'status': 'open',
        'truckId': _selectedTruck.id,
        'truckLabel': _selectedTruck.label,
        'initialKm': initialKm,
        'initialAt': FieldValue.serverTimestamp(),
        'initialAtClient': now.toIso8601String(),
        'openedByName': openedByName,
        'finalKm': null,
        'finalAt': null,
        'closedByName': null,
        'totalKm': null,
        'userUid': widget.profile.uid,
        'userName': widget.profile.fullName,
        'userEmail': widget.profile.email,
        'platform': logisticsPlatformLabel(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.profile.uid,
      });
      if (!mounted) return;
      _toast('Jornada iniciada correctamente.');
    } catch (e) {
      _toast('No se pudo iniciar el día: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _initialKm.dispose();
    _openedByName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined, size: 30, color: Color(0xFF006341)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Inicio de jornada',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Antes de usar la app en Android con el usuario de logística, tenés que seleccionar el camión y registrar los kilómetros iniciales del día.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _truckId,
                decoration: const InputDecoration(labelText: 'Seleccionar camión'),
                items: logisticsTruckOptions
                    .map(
                      (truck) => DropdownMenuItem<String>(
                        value: truck.id,
                        child: Text(truck.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving ? null : (value) => setState(() => _truckId = value ?? logisticsTruckOptions.first.id),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _openedByName,
                decoration: const InputDecoration(
                  labelText: 'Nombre de quien abre el camión',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _initialKm,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Km iniciales',
                  hintText: 'Ejemplo: 125430',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _startDay,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(_saving ? 'Guardando...' : 'Iniciar día'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogisticsDayActiveCard extends StatefulWidget {
  final AppUserProfile profile;
  final DocumentReference<Map<String, dynamic>> dayRef;
  final Map<String, dynamic> data;

  const LogisticsDayActiveCard({
    super.key,
    required this.profile,
    required this.dayRef,
    required this.data,
  });

  @override
  State<LogisticsDayActiveCard> createState() => _LogisticsDayActiveCardState();
}

class _LogisticsDayActiveCardState extends State<LogisticsDayActiveCard> {
  bool _closing = false;
  bool _showCloseForm = false;
  final _finalKmController = TextEditingController();
  final _closedByNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _closedByNameController.text = widget.profile.fullName;
  }

  @override
  void dispose() {
    _finalKmController.dispose();
    _closedByNameController.dispose();
    super.dispose();
  }

  Future<void> _confirmCloseDay() async {
    final initialKm = (widget.data['initialKm'] as num?)?.toInt();
    final finalKm = int.tryParse(_finalKmController.text.trim());
    final closedByName = _closedByNameController.text.trim();

    if (closedByName.isEmpty) {
      _toast('Ingresá el nombre de quien cierra el camión.');
      return;
    }
    if (finalKm == null) {
      _toast('Ingresá un kilometraje final válido.');
      return;
    }
    if (initialKm != null && finalKm < initialKm) {
      _toast('Los km finales no pueden ser menores a los km iniciales.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _closing = true);
    try {
      await widget.dayRef.set({
        'finalKm': finalKm,
        'finalAt': FieldValue.serverTimestamp(),
        'finalAtClient': DateTime.now().toLocal().toIso8601String(),
        'totalKm': initialKm == null ? null : finalKm - initialKm,
        'status': 'closed',
        'closedByName': closedByName,
        'closedByUid': widget.profile.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.profile.uid,
      }, SetOptions(merge: true));
      if (!mounted) return;
      _finalKmController.clear();
      _toast('Día cerrado correctamente.');
    } catch (e) {
      _toast('No se pudo cerrar el día: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.data['initialAt'];
    final startedLabel = startedAt is Timestamp
        ? DateFormat('dd/MM/yyyy HH:mm').format(startedAt.toDate())
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFFEAF5EF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.route_outlined, color: Color(0xFF006341)),
              Text(
                'Jornada activa · ${_displayText(widget.data['truckLabel'])}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              _InfoChip(label: 'Abre', value: _displayText(widget.data['openedByName'])),
              _InfoChip(label: 'Km iniciales', value: '${widget.data['initialKm'] ?? '-'}'),
              _InfoChip(label: 'Iniciado', value: startedLabel),
              FilledButton.tonalIcon(
                onPressed: _closing
                    ? null
                    : () {
                        setState(() {
                          _showCloseForm = !_showCloseForm;
                          if (_closedByNameController.text.trim().isEmpty) {
                            _closedByNameController.text = widget.profile.fullName;
                          }
                        });
                      },
                icon: const Icon(Icons.flag_outlined),
                label: Text(_showCloseForm ? 'Ocultar cierre' : 'Cerrar día'),
              ),
              if (_showCloseForm)
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _closedByNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de quien cierra el camión',
                    ),
                  ),
                ),
              if (_showCloseForm)
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _finalKmController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Km finales',
                    ),
                  ),
                ),
              if (_showCloseForm)
                FilledButton.icon(
                  onPressed: _closing ? null : _confirmCloseDay,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_closing ? 'Cerrando...' : 'Confirmar cierre'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006341).withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF5E5E5E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
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
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Resumen de pedidos',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'Vista general del estado de entregas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricCard(
                  label: 'Total pedidos',
                  value: '$total',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF006341),
                  bgColor: const Color(0xFFE8F5EE),
                ),
                _MetricCard(
                  label: 'Pendientes',
                  value: '$pendientes',
                  icon: Icons.pending_actions,
                  color: const Color(0xFFB45309),
                  bgColor: const Color(0xFFFFF7ED),
                ),
                _MetricCard(
                  label: 'Entregados',
                  value: '$entregados',
                  icon: Icons.task_alt,
                  color: const Color(0xFF1B617C),
                  bgColor: const Color(0xFFE8F4F8),
                ),
                _MetricCard(
                  label: 'Parciales',
                  value: '$parciales',
                  icon: Icons.rule_folder_outlined,
                  color: const Color(0xFF898D4A),
                  bgColor: const Color(0xFFF5F5E8),
                ),
                _MetricCard(
                  label: 'Fallidos',
                  value: '$fallidos',
                  icon: Icons.error_outline,
                  color: const Color(0xFFB91C1C),
                  bgColor: const Color(0xFFFFF0F0),
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
  final Color color;
  final Color bgColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7E7E7E),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class NewOrderPage extends StatefulWidget {
  final AppUserProfile profile;

  const NewOrderPage({super.key, required this.profile});

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  static const String _parserBuildStamp = 'parser-2026-03-31-2145';

  final uuid = const Uuid();
  final _invoice = TextEditingController();
  final _customer = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final List<TextEditingController> _addresses = [TextEditingController()];
  final _notes = TextEditingController();
  final _trips = TextEditingController(text: '1');
  int _pickupUnits = 0;

  int priority = 2;
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));
  String _deliveryShift = 'mañana';
  List<Uint8List> pdfFilesBytes = [];
  List<String> pdfFileNames = [];
  List<Uint8List> invoicePhotoBytes = [];
  List<String> invoicePhotoNames = [];
  List<ParsedInvoiceLine> _invoiceItems = const [];
  String _invoiceTaxableAmount = '';
  String _invoiceIvaAmount = '';
  String _invoiceTotalAmount = '';
  String _invoiceCurrency = '';
  String? _invoiceSourceFileName;
  String? _invoiceReadMessage;
  bool _parsingInvoice = false;
  bool saving = false;
  bool _showSchedulePicker = false;

  String get _currentMapLink {
    final first = _addresses.first.text.trim();
    return first.isEmpty ? '' : _mapsUrlForQuery(first);
  }

  DateTime get _committedDateTime => DateTime(
        _deliveryDate.year,
        _deliveryDate.month,
        _deliveryDate.day,
        _deliveryShift == 'mañana' ? 9 : 15,
      );

  String get _deliveryDateLabel =>
      '${DateFormat('dd/MM/yyyy').format(_deliveryDate)} · ${_deliveryShift == 'mañana' ? 'Mañana' : 'Tarde'}';

    String get _invoiceItemsSummaryText =>
      _invoiceItems.map(_invoiceItemSummaryLine).join('\n');

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() {
      pdfFilesBytes = [file.bytes!];
      pdfFileNames = [file.name];
      _parsingInvoice = true;
      _invoiceReadMessage = null;
    });

    try {
      final parsed = await InvoiceParser.parsePdfBytes(
        file.bytes!,
        sourceFileName: file.name,
      );

      if (parsed == null) {
        setState(() {
          _invoiceReadMessage =
              'No se pudieron leer datos automaticamente. Usa un PDF digital con texto seleccionable.';
        });
        return;
      }

      _applyParsedInvoice(parsed);
      setState(() {
        _invoiceReadMessage = parsed.lines.isEmpty
            ? 'Factura leida, pero no se detectaron articulos.'
            : 'Factura leida automaticamente. Articulos detectados: ${parsed.lines.length}';
      });
    } catch (e) {
      setState(() {
        _invoiceReadMessage = 'No se pudo leer la factura: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _parsingInvoice = false);
      }
    }
  }

  void _applyParsedInvoice(ParsedInvoiceData parsed) {
    if (parsed.invoiceNumber.isNotEmpty) {
      _invoice.text = parsed.invoiceNumber.replaceFirst(
        RegExp(r'^0+(?=\d)'),
        '',
      );
    }
    if (parsed.customerName.isNotEmpty) {
      _customer.text = parsed.customerName;
    }

    _invoiceItems = parsed.lines;
    _invoiceTaxableAmount = parsed.taxableAmount;
    _invoiceIvaAmount = parsed.ivaAmount;
    _invoiceTotalAmount = parsed.totalAmount;
    _invoiceCurrency = parsed.currency;
    _invoiceSourceFileName = parsed.sourceFileName;
    _rebuildInvoiceArticlesField();
  }

  void _rebuildInvoiceArticlesField() {
    if (_invoiceItems.isEmpty) {
      _pickupUnits = 0;
      return;
    }

    final pickupCount =
        _invoiceItems.where((item) => item.pickedUpAtCounter).length;
    _pickupUnits = pickupCount;
  }

  void _toggleCounterPickupItem(int index, bool? value) {
    final next = value ?? false;
    setState(() {
      _invoiceItems = _invoiceItems
          .asMap()
          .entries
          .map(
            (entry) => entry.key == index
                ? entry.value.copyWith(pickedUpAtCounter: next)
                : entry.value,
          )
          .toList();
      _rebuildInvoiceArticlesField();
    });
  }

  String _invoiceItemSummaryLine(ParsedInvoiceLine item) {
    final qty = item.quantity.isEmpty ? '' : ' x ${item.quantity}';
    return '${item.code} - ${item.description}$qty';
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

  void _toggleSchedulePicker() {
    setState(() => _showSchedulePicker = !_showSchedulePicker);
  }

  Future<void> _saveOrder() async {
    if (_invoice.text.trim().isEmpty ||
        _customer.text.trim().isEmpty ||
        _contact.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _addresses.first.text.trim().isEmpty) {
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
        'invoiceParsedItems':
          _invoiceItems.isEmpty ? null : _invoiceItems.map((e) => e.toMap()).toList(),
        'invoiceTaxableAmount':
          _invoiceTaxableAmount.isEmpty ? null : _invoiceTaxableAmount,
        'invoiceIvaAmount': _invoiceIvaAmount.isEmpty ? null : _invoiceIvaAmount,
        'invoiceTotalAmount':
          _invoiceTotalAmount.isEmpty ? null : _invoiceTotalAmount,
        'invoiceSourceFileName': _invoiceSourceFileName,
        'clienteNombreSnapshot': _customer.text.trim(),
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
        'committedDate': _committedDateTime,
        'deliveryDate': DateTime(
          _deliveryDate.year,
          _deliveryDate.month,
          _deliveryDate.day,
        ),
        'deliveryShift': _deliveryShift,
        'mapLink': _currentMapLink.isEmpty ? null : _currentMapLink,
        'itemsSummary': _invoiceItemsSummaryText.trim().isEmpty
            ? null
          : _invoiceItemsSummaryText.trim(),
        'invoiceItemsText': _invoiceItemsSummaryText.trim().isEmpty
          ? null
          : _invoiceItemsSummaryText.trim(),
        'totalTrips': int.tryParse(_trips.text.trim()) ?? 1,
        'counterPickupUnits': _pickupUnits,
        'direccionTexto': _addresses.first.text.trim(),
        'direccionesAdicionales': _addresses.length > 1
            ? _addresses.skip(1).map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
            : null,
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
      for (final c in _addresses) c.clear();
      if (_addresses.length > 1) {
        for (final c in _addresses.skip(1).toList()) c.dispose();
        _addresses.removeRange(1, _addresses.length);
      }
      _notes.clear();
      _deliveryDate = DateTime.now().add(const Duration(days: 1));
      _deliveryShift = 'mañana';
      _trips.text = '1';
      _pickupUnits = 0;
      priority = 2;
      pdfFilesBytes = [];
      pdfFileNames = [];
      invoicePhotoBytes = [];
      invoicePhotoNames = [];
      _invoiceItems = const [];
      _invoiceTaxableAmount = '';
      _invoiceIvaAmount = '';
      _invoiceTotalAmount = '';
      _invoiceCurrency = '';
      _invoiceSourceFileName = null;
      _invoiceReadMessage = null;

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
    for (final c in _addresses) c.dispose();
    _notes.dispose();
    _trips.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.canCreateOrders) {
      return const AccessDeniedCard(
        title: 'Nuevo pedido',
        message: 'Tu usuario no tiene permiso para crear pedidos.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF006341), Color(0xFF1B617C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_box_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Nueva venta + pedido',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _parserBuildStamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _parsingInvoice ? null : pickPdf,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        _parsingInvoice
                            ? 'Leyendo factura...'
                            : 'Ingresar factura PDF',
                      ),
                    ),
                    Text(
                      _invoiceSourceFileName == null
                          ? 'Lectura automatica para PDF digital'
                          : 'Factura: $_invoiceSourceFileName',
                    ),
                  ],
                ),
                if (_invoiceReadMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_invoiceReadMessage!),
                ],
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
                    // ── Direcciones (múltiples) ──────────────────────────
                    for (int di = 0; di < _addresses.length; di++) ...[
                      _field(
                        width: 500,
                        child: TextField(
                          controller: _addresses[di],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: di == 0 ? 'Dirección *' : 'Dirección adicional ${di + 1}',
                            suffixIcon: di > 0
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    tooltip: 'Quitar dirección',
                                    onPressed: () => setState(() {
                                      _addresses[di].dispose();
                                      _addresses.removeAt(di);
                                    }),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                    _field(
                      width: 500,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Agregar otra dirección'),
                        onPressed: () => setState(() {
                          _addresses.add(TextEditingController());
                        }),
                      ),
                    ),
                    _field(
                      width: 320,
                      child: InkWell(
                        onTap: _toggleSchedulePicker,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha de entrega *',
                            suffixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          child: Text(_deliveryDateLabel),
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
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Retiro mostrador (unidades)',
                        ),
                        child: Text(
                          '$_pickupUnits',
                          style: const TextStyle(fontSize: 16),
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
                if (_showSchedulePicker) ...[
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seleccionar fecha de entrega',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CalendarDatePicker(
                            initialDate: _deliveryDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                            onDateChanged: (value) {
                              setState(() => _deliveryDate = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Turno',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'mañana',
                                label: Text('Mañana'),
                                icon: Icon(Icons.wb_sunny_outlined),
                              ),
                              ButtonSegment<String>(
                                value: 'tarde',
                                label: Text('Tarde'),
                                icon: Icon(Icons.brightness_3_outlined),
                              ),
                            ],
                            selected: <String>{_deliveryShift},
                            onSelectionChanged: (selection) {
                              setState(() => _deliveryShift = selection.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: _toggleSchedulePicker,
                              child: const Text('Listo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    final mapBox = SizedBox(
                      width: compact ? 160 : 180,
                      height: compact ? 160 : 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buildGoogleMapsPreview(
                          address: _addresses.first.text,
                          height: compact ? 160 : 180,
                        ),
                      ),
                    );

                    if (compact) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: mapBox,
                      );
                    }

                    return Align(
                      alignment: Alignment.centerRight,
                      child: mapBox,
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Articulos de la factura',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_invoiceItems.isEmpty)
                  const Text(
                    'No se detectaron articulos en el PDF.',
                    style: TextStyle(color: Color(0xFF66666A)),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Mostrador')),
                        DataColumn(label: Text('Codigo')),
                        DataColumn(label: Text('Descripcion')),
                        DataColumn(label: Text('Precio')),
                        DataColumn(label: Text('Tasa')),
                        DataColumn(label: Text('Cant')),
                        DataColumn(label: Text('Desc. (%)')),
                        DataColumn(label: Text('Total')),
                      ],
                      rows: _invoiceItems
                          .asMap()
                          .entries
                          .map(
                            (entry) => DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: entry.value.pickedUpAtCounter,
                                    onChanged: (value) =>
                                        _toggleCounterPickupItem(entry.key, value),
                                  ),
                                ),
                                DataCell(Text(entry.value.code)),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(entry.value.description),
                                  ),
                                ),
                                DataCell(Text(entry.value.price)),
                                DataCell(Text(entry.value.taxRate)),
                                DataCell(Text(entry.value.quantity)),
                                DataCell(Text(entry.value.discountPercent)),
                                DataCell(Text(entry.value.total)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
                ),
                if (_invoiceItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_invoiceItems.length} articulo(s) detectado(s) en la factura.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InvoiceTotalChip(
                        label: 'Moneda',
                        value: _invoiceCurrency.isEmpty ? '-' : _invoiceCurrency,
                      ),
                      _InvoiceTotalChip(
                        label: 'Monto imponible',
                        value: _invoiceTaxableAmount,
                      ),
                      _InvoiceTotalChip(
                        label: 'IVA',
                        value: _invoiceIvaAmount,
                      ),
                      _InvoiceTotalChip(
                        label: 'Total',
                        value: _invoiceTotalAmount,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      pdfFileNames.isEmpty
                          ? 'Sin PDF todavia'
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
        ],
      ),
    ),
  ],
);
  }

  Widget _field({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }
}

class _InvoiceTotalChip extends StatelessWidget {
  final String label;
  final String value;

  const _InvoiceTotalChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006341).withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5E5E5E),
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF006341),
            ),
          ),
        ],
      ),
    );
  }
}

class UsersPage extends StatelessWidget {
  final AppUserProfile profile;

  const UsersPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
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
                                  if (kLocalOnlyMode) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          kLocalOnlyWriteBlockedMessage,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  await doc.reference.update({'role': value.name});
                                },
                              ),
                            ),
                            FilterChip(
                              selected: active,
                              label: Text(active ? 'Activo' : 'Inactivo'),
                              onSelected: (_) async {
                                if (kLocalOnlyMode) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        kLocalOnlyWriteBlockedMessage,
                                      ),
                                    ),
                                  );
                                  return;
                                }
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
      return 'Herramientas: resumen, pendientes, entregados, inicio/cierre de jornada con camión y kilómetros, y cierre de entregas con foto y ubicación. No puede crear pedidos.';
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

String _displayText(dynamic value, [String fallback = '-']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
