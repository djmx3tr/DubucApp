import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/unified_notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => UnifiedNotificationService()),
      ],
      child: const DubucApp(),
    ),
  );
}

class DubucApp extends StatelessWidget {
  const DubucApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dubuc & CO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ScannerScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Déconnecter WebSocket proprement
    context.read<UnifiedNotificationService>().disconnectWebSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final notificationService = context.read<UnifiedNotificationService>();
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App en background ou fermée - déconnecter WebSocket
        notificationService.disconnectWebSocket();
        debugPrint('App en background - WebSocket déconnecté');
        break;
        
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // App active ou en avant-plan - reconnecter si nécessaire
        if (!notificationService.isWebSocketConnected) {
          notificationService.reconnectWebSocket();
          debugPrint('App active - WebSocket reconnexion');
        }
        break;
        
      case AppLifecycleState.hidden:
        // App cachée - déconnecter pour économiser la batterie
        notificationService.disconnectWebSocket();
        debugPrint('App cachée - WebSocket déconnecté');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Consumer<UnifiedNotificationService>(
        builder: (context, unifiedService, child) {
          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Accueil',
              ),
              const NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: 'Scanner',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unifiedService.unreadCount > 0,
                  label: Text('${unifiedService.unreadCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unifiedService.unreadCount > 0,
                  label: Text('${unifiedService.unreadCount}'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'Alertes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Paramètres',
              ),
            ],
          );
        },
      ),
    );
  }
}
