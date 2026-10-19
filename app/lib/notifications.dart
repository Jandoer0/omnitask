/// Локальные уведомления о дедлайнах.
///
/// Android — flutter_local_notifications; Windows — local_notifier.
/// Никакой сети: планировщик живёт только пока открыто приложение,
/// проверяет дедлайны раз в 15 минут и при старте.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

import 'models.dart';

class NotificationService {
  final _local = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  final Set<String> _shown = {}; // дедупликация в рамках сессии

  Future<void> init() async {
    try {
      if (Platform.isAndroid) {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        await _local.initialize(
            const InitializationSettings(android: android));
        // Android 13+: запрос разрешения на уведомления.
        final impl = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await impl?.requestNotificationsPermission();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await localNotifier.setup(
          appName: 'Omnitask Local',
        );
      }
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  /// Запуск периодической проверки дедлайнов.
  void startPeriodicCheck(Future<List<VaultTask>> Function() fetch) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) async {
      final tasks = await fetch();
      _check(tasks);
    });
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Проверить задачи и показать уведомления о близких дедлайнах.
  void check(List<VaultTask> tasks) => _check(tasks);

  void _check(List<VaultTask> tasks) {
    for (final t in tasks) {
      if (t.deadline == null) continue;
      final overdue = t.deadline!.isBefore(DateTime.now());
      final key = '${t.id}|${t.deadline!.millisecondsSinceEpoch}|$overdue';
      if (_shown.contains(key)) continue;
      _shown.add(key);
      final title = overdue
          ? 'Просрочена: ${t.title}'
          : 'Скоро дедлайн: ${t.title}';
      final body = overdue
          ? 'Дедлайн был ${_fmt(t.deadline!)} — требуется внимание'
          : 'Дедлайн ${_fmt(t.deadline!)}';
      _notify(title, body);
    }
  }

  static String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    return date;
  }

  void _notify(String title, String body) {
    try {
      if (Platform.isAndroid) {
        _local.show(
          title.hashCode & 0x7fffffff,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'deadlines',
              'Дедлайны задач',
              channelDescription: 'Напоминания о задачах с дедлайнами',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final n = LocalNotification(title: title, body: body);
        n.show();
      }
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }
}
