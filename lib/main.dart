import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/loading.dart';
import 'services/auth_service.dart';
import 'screens/landing_page.dart';
import 'screens/home.dart';
import 'services/settings_service.dart';
import 'hive/hive_service.dart';
import 'widgets/banner_ad_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  runApp(const MinesweeperApp());
}

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),

        ChangeNotifierProvider(create: (context) => SettingsService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        title: 'Mine Master',

        builder: kIsWeb
            ? null
            : (context, child) => Stack(
                  children: [
                    child!,
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: const BannerAdWidget(),
                    ),
                  ],
                ),

        theme: ThemeData(
          useMaterial3: true,

          scaffoldBackgroundColor: const Color(0xFF0B1E3D), // Navy Blue

          colorScheme: ColorScheme.dark(
            primary: Color.fromARGB(255, 255, 136, 0),

            secondary: const Color(0xFFC0C0C0), // Silver

            surface: const Color(0xFF102A43),
          ),

          textTheme: ThemeData.dark().textTheme
              .copyWith(
                bodyLarge: const TextStyle(
                  color: Colors.white,

                  decoration: TextDecoration.none,
                ),

                bodyMedium: const TextStyle(
                  color: Color(0xFFC0C0C0),

                  decoration: TextDecoration.none,
                ),

                titleLarge: const TextStyle(
                  color: Color.fromARGB(255, 255, 136, 0),

                  fontWeight: FontWeight.bold,

                  decoration: TextDecoration.none,
                ),
              )
              .apply(decoration: TextDecoration.none),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 255, 136, 0),

              foregroundColor: const Color(0xFF0B1E3D),

              textStyle: const TextStyle(fontWeight: FontWeight.bold),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),

          iconTheme: const IconThemeData(color: Colors.white),
        ),

        home: const SplashToAuthWrapper(),
      ),
    );
  }
}

class SplashToAuthWrapper extends StatefulWidget {
  const SplashToAuthWrapper({super.key});

  @override
  State<SplashToAuthWrapper> createState() => _SplashToAuthWrapperState();
}

class _SplashToAuthWrapperState extends State<SplashToAuthWrapper> {
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();

    // Initialize auth state when app starts

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = context.read<AuthService>();

      final settingsService = context.read<SettingsService>();

      await authService.initializeAuth(); // syncs pending results internally
      await settingsService.initializeSettings();

    });
  }

  void _onSplashComplete() {
    setState(() {
      _splashComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return AnimatedSplashScreen(onSplashComplete: _onSplashComplete);
    }

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isLoggedIn = authService.isLoggedIn == true;

        return isLoggedIn ? const HomeScreen() : const LandingPage();
      },
    );
  }
}
