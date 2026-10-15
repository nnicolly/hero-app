import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

bool _converted = false;

/// Capturas opcionais em cache temporário, sem tocar nos bancos do usuário.
Future<void> reviewCapture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REVIEW_SCREENSHOTS')) return;
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!_converted) {
    await binding.convertFlutterSurfaceToImage();
    _converted = true;
    addTearDown(() => _converted = false);
  }
  await tester.pumpAndSettle();
  final bytes = await binding.takeScreenshot(name);
  // Android limpa code_cache a cada atualização do APK entre arquivos de teste.
  // O cache comum mantém as capturas disponíveis até terminar a revisão.
  final directory = Platform.isAndroid
      ? Directory('${Directory.systemTemp.parent.path}/cache/review')
      : Directory('${Directory.systemTemp.path}/review');
  await directory.create(recursive: true);
  final file = File('${directory.path}/review_$name.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('Captura de revisão: ${file.path}');
}
