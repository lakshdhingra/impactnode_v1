import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_page.dart';
import 'background_service.dart';
import 'SOS.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'impactnode_channel',
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'ImpactNode Active',
      initialNotificationContent: 'Monitoring for crashes',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: backgroundServiceStart,
      onBackground: (_) => true,
    ),
  );

  await Supabase.initialize(
    url: 'https://ajpyceoclvhnngbityaz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqcHljZW9jbHZobm5nYml0eWF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxNTkwNDAsImV4cCI6MjA3OTczNTA0MH0.QEk5NmHF-vVddzjTv4lLsMK9z9UDPZZs36H1qSkHz_o',
  );

  runApp(const MyApp());
}

/* ───────────────────────── APP ROOT ───────────────────────── */

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const AuthPage(),
      routes: {
        '/sos': (context) => const SOSPreview(),
      },
    );
  }
}

/* ───────────────────────── DRAWER ───────────────────────── */

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 60,
                ),
                const SizedBox(height: 10),
                const Text(
                  "ImpactNode",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text("SOS"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/sos');
            },
          ),

          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Theme"),
            onTap: () {
              Navigator.pop(context);
              appState.toggleTheme();
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help"),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text("Help"),
                  content: Text(
                    "ImpactNode automatically detects vehicle crashes.\n\n"
                    "If a crash is detected, SOS is triggered after a countdown.\n"
                    "You can cancel the SOS during this time.",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── CRASH SOS SCREEN ───────────────────────── */

class CrashSOSScreen extends StatefulWidget {
  const CrashSOSScreen({super.key});

  @override
  State<CrashSOSScreen> createState() => _CrashSOSScreenState();
}

class _CrashSOSScreenState extends State<CrashSOSScreen> {
  double gForce = 0;
  double rotation = 0;
  double speed = 0;

  bool sosActive = false;
  int countdown = 10;
  Timer? timer;
  Position? lastPos;

  final List<String> contacts = [
    "9999999999",
    "8888888888",
    "7777777777",
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _requestPermissions();
    FlutterBackgroundService().startService();
    _startSensors();
    await _startLocation();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();

    LocationPermission loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _startSensors() {
    accelerometerEvents.listen((e) {
      final mag = sqrt(
        pow(e.x / 9.8, 2) +
            pow(e.y / 9.8, 2) +
            pow(e.z / 9.8, 2),
      );
      gForce = (mag - 1).abs();
      _checkCrash();
      setState(() {});
    });

    gyroscopeEvents.listen((e) {
      rotation = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      _checkCrash();
      setState(() {});
    });
  }

  Future<void> _startLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream().listen((p) {
      lastPos = p;
      speed = p.speed * 3.6;
      _checkCrash();
      setState(() {});
    });
  }

  void _checkCrash() {
    if (sosActive) return;
    if (gForce > 3.0 && rotation > 4.0 && speed > 25) {
      _startSOS();
    }
  }

  void _startSOS() {
    sosActive = true;
    countdown = 10;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      countdown--;
      if (countdown == 0) {
        t.cancel();
        _callSOS();
        _sendSMS();
      }
      setState(() {});
    });
  }

  Future<void> _callSOS() async {
    await launchUrl(Uri(scheme: 'tel', path: '112'));
  }

  Future<void> _sendSMS() async {
    if (lastPos == null) return;

    final link =
        "https://maps.google.com/?q=${lastPos!.latitude},${lastPos!.longitude}";

    final message =
        "EMERGENCY ALERT\nPossible accident detected.\n\nLocation:\n$link";

    for (final number in contacts) {
      final uri = Uri.parse(
        "smsto:$number?body=${Uri.encodeComponent(message)}",
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _cancelSOS() {
    timer?.cancel();
    sosActive = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 28,
            ),
            const SizedBox(width: 10),
            const Text("ImpactNode – Crash SOS"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: sosActive
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 90, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    "Calling SOS in $countdown",
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _cancelSOS,
                    child: const Text("Cancel SOS"),
                  ),
                ],
              )
            : Column(
                children: [
                  _card(Icons.speed, "Speed",
                      "${speed.toStringAsFixed(1)} km/h"),
                  _card(Icons.flash_on, "Impact",
                      "${gForce.toStringAsFixed(2)} g"),
                  _card(Icons.rotate_right, "Rotation",
                      rotation.toStringAsFixed(2)),
                  const Spacer(),
                  _btn(Icons.call, "CALL SOS", Colors.red, _callSOS),
                  const SizedBox(height: 10),
                  _btn(Icons.sms, "SEND SOS SMS", Colors.orange, _sendSMS),
                ],
              ),
      ),
    );
  }

  Widget _card(IconData icon, String title, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }

  Widget _btn(
      IconData icon, String text, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 55),
      ),
    );
  }
}
