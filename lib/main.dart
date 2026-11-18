import 'package:flutter/material.dart';
import 'core/api.dart';
import 'pages/dashboard.dart';
import 'pages/users.dart';
import 'pages/requests.dart';
import 'pages/settings.dart';
import 'pages/staff.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApi();
  runApp(const AdminApp());
}

ThemeData _t(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B), brightness: b);
  return ThemeData(
    useMaterial3: true, colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1514) : const Color(0xFFF2FAF8),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: scheme.onSurface)),
    cardTheme: CardThemeData(elevation: 0, color: dark ? const Color(0xFF17211F) : Colors.white, margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant.withOpacity(0.35)))),
    navigationBarTheme: NavigationBarThemeData(height: 66, backgroundColor: dark ? const Color(0xFF121A18) : Colors.white),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF1D2A27) : const Color(0xFFE8F5F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'Earning Admin', debugShowCheckedModeBanner: false,
      theme: _t(Brightness.light), darkTheme: _t(Brightness.dark), home: const Gate());
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<dynamic>(
      stream: pb.authStore.onChange,
      builder: (c, a) {
        if (!pb.authStore.isValid) return const Login();
        return FutureBuilder<String>(
          future: loadRole(),
          builder: (c, t) {
            if (!t.hasData) return const Scaffold(body: Loading());
            final role = t.data!;
            if (!['super_admin', 'admin', 'support'].contains(role)) return const Denied();
            return Home(role: role);
          });
      });
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _L();
}

class _L extends State<Login> {
  bool busy = false;
  Future<void> go() async {
    setState(() => busy = true);
    try {
      await loginWithGoogle();
    } catch (e) { if (mounted) toast(context, e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext c) => Scaffold(body: Container(
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF004D40), kBrand, kBrand2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      const Spacer(),
      Container(padding: const EdgeInsets.all(22), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: const Icon(Icons.admin_panel_settings, size: 64, color: Colors.white)),
      const SizedBox(height: 18),
      const Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Manage users, payments and settings', style: TextStyle(color: Colors.white70)),
      const Spacer(),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: busy ? null : go,
          icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
          label: const Text('Sign in with Google'))))),
    ])))));
}

class Denied extends StatelessWidget {
  const Denied({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.block, size: 48, color: Colors.red)),
    const SizedBox(height: 14), const Text('Access denied', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4), const Text('Your account has no admin role.'),
    const SizedBox(height: 16), FilledButton.tonal(onPressed: () => logout(), child: const Text('Sign out'))]))));
}

class Home extends StatefulWidget {
  final String role;
  const Home({super.key, required this.role});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  int i = 0;
  bool get admin => widget.role != 'support';
  bool get sup => widget.role == 'super_admin';
  @override
  Widget build(BuildContext c) {
    final items = <(String, IconData, Widget)>[
      ('Dashboard', Icons.dashboard, const DashboardPage()),
      ('Users', Icons.people, UsersPage(role: widget.role)),
      ('Requests', Icons.payments, RequestsPage(canAct: admin)),
      if (admin) ('Notifications', Icons.notifications, const NotifyPage()),
      if (admin) ('Banners', Icons.image, const BannersPage()),
      if (sup) ('App Settings', Icons.tune, const SettingsPage()),
      if (sup) ('Staff & Logs', Icons.security, const StaffPage()),
    ];
    if (i >= items.length) i = 0;
    return Scaffold(
      appBar: AppBar(title: Text(items[i].$1), actions: [
        Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: kBrand.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
            child: Text(widget.role.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: kBrand, fontWeight: FontWeight.w800, fontSize: 11)))]),
      drawer: Drawer(child: Column(children: [
        Container(width: double.infinity, padding: EdgeInsets.fromLTRB(20, MediaQuery.of(c).padding.top + 24, 20, 24),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF004D40), kBrand, kBrand2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30)),
            const SizedBox(height: 12),
            const Text('Earning Admin', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(widget.role.replaceAll('_', ' '), style: const TextStyle(color: Colors.white70)),
          ])),
        Expanded(child: ListView(padding: const EdgeInsets.all(10), children: [
          for (var k = 0; k < items.length; k++)
            ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: Icon(items[k].$2), title: Text(items[k].$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                selected: k == i, selectedTileColor: kBrand.withOpacity(0.12), onTap: () { setState(() => i = k); Navigator.pop(c); }),
          const Divider(),
          ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: () => logout()),
        ])),
      ])),
      body: items[i].$3,
    );
  }
}
