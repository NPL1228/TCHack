import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/finance_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/passcode_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env keys
  await dotenv.load(fileName: ".env");

  // Initialize Hive
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  await FinanceProvider.openBoxes();

  runApp(const AiLedgeApp());
}

class AiLedgeApp extends StatefulWidget {
  const AiLedgeApp({super.key});

  @override
  State<AiLedgeApp> createState() => _AiLedgeAppState();
}

class _AiLedgeAppState extends State<AiLedgeApp> with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock on cold start if passcode is enabled
    _locked = SettingsService.passcodeEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Lock when app goes to background
      if (SettingsService.passcodeEnabled) {
        setState(() => _locked = true);
      }
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceProvider()..init(),
      child: MaterialApp(
        title: 'AiLedge – Personal Finance Planner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _locked
            ? PasscodeScreen(mode: PasscodeMode.verify, onSuccess: _unlock)
            : const SplashScreen(),
      ),
    );
  }
}
