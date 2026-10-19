/// Конфигурация приложения вне хранилища: путь к папке vault.
///
/// Хранится в JSON в каталоге данных приложения (не внутри vault,
/// чтобы не было проблемы «курицы и яйца»).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppConfig {
  static const _fileName = 'omnitask_config.json';

  /// Прочитать сохранённый путь к хранилищу (null — ещё не выбрано).
  static Future<String?> loadVaultPath() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      final path = data['vaultPath'] as String?;
      if (path == null || path.isEmpty) return null;
      if (!await Directory(path).exists()) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Сохранить путь к хранилищу.
  static Future<void> saveVaultPath(String path) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'vaultPath': path}));
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Каталог по умолчанию для предложения при первом запуске
  /// (Документы/Omnitask; на Android — внешние документы).
  static Future<String> defaultVaultPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.parent.path, 'Documents', 'Omnitask');
  }
}
