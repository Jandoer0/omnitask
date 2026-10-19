import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'app_controller.dart';
import 'notifications.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

final notificationService = NotificationService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OmnitaskApp());
}

class OmnitaskApp extends StatelessWidget {
  const OmnitaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(),
      child: MaterialApp(
        title: 'Omnitask Local',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Bootstrap(),
      ),
    );
  }
}

/// Выбирает стартовый экран: онбординг (хранилище не выбрано) или главная.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  String? _vaultPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = context.read<AppController>();
    final path = await AppConfig.loadVaultPath();
    if (!mounted) return;
    if (path != null) {
      controller.openVault(path);
      await notificationService.init();
      notificationService.startPeriodicCheck(
          () async => controller.tasksNeedingReminder());
      notificationService.check(controller.tasksNeedingReminder());
    }
    setState(() {
      _vaultPath = path;
      _loading = false;
    });
  }

  Future<void> _onVaultSelected(String path) async {
    await AppConfig.saveVaultPath(path);
    if (!mounted) return;
    context.read<AppController>().openVault(path);
    await notificationService.init();
    notificationService.startPeriodicCheck(
        () async => context.read<AppController>().tasksNeedingReminder());
    setState(() => _vaultPath = path);
  }

  /// Смена хранилища из настроек.
  Future<void> _changeVault(String path) => _onVaultSelected(path);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_vaultPath == null) {
      return OnboardingScreen(onVaultSelected: _onVaultSelected);
    }
    return HomeScreen(onChangeVault: _changeVault);
  }
}
