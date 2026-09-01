import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/accounting_repository.dart';
import 'theme/app_theme.dart';
import 'views/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }
  runApp(const FamilyPouchApp());
}

class FamilyPouchApp extends StatelessWidget {
  const FamilyPouchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccountingRepository(),
      child: MaterialApp(
        title: 'FamilyPouch • Family Accounting & Receipt OCR',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainShell(),
      ),
    );
  }
}
