import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/tv_theme.dart';
import 'features/home/tv_home_screen.dart';
import 'features/pairing/tv_pairing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TV apps are always landscape
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const ProviderScope(child: DirectNetTvApp()));
}

class DirectNetTvApp extends StatelessWidget {
  const DirectNetTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DirectNet TV',
      debugShowCheckedModeBanner: false,
      theme: TvTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (_) => const TvHomeScreen(),
        '/pairing': (_) => const TvPairingScreen(),
      },
    );
  }
}
