/// Оформение Omnitask Local — порт визуального языка справочного проекта
/// mcp-todo: тёмная шапка #22384d, фон #35506b, белые карточки, slate-текст.
library;

import 'package:flutter/material.dart';

class AppColors {
  static const header = Color(0xFF22384D);
  static const background = Color(0xFF35506B);
  static const card = Colors.white;
  static const text = Color(0xFF1E293B);
  static const textMuted = Color(0xFF64748B);
  static const accent = Color(0xFF3B82F6); // blue-500
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFF87171);
  static const orange = Color(0xFFF97316);
  static const slate400 = Color(0xFF94A3B8);
  static const white60 = Color(0x99FFFFFF);

  /// Приоритет: 1 низкий (серый), 2 средний (синий), 3 высокий (красный).
  static Color priorityDot(int priority) {
    switch (priority) {
      case 3:
        return const Color(0xFFEF4444);
      case 1:
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

/// '#aabbcc' → Color.
Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

/// «12 окт.» в текущем году, иначе «12 окт. 2027» (как formatDate в референсе).
String formatShortDate(DateTime? d) {
  if (d == null) return '';
  const months = [
    'янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.',
    'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
  ];
  final now = DateTime.now();
  final year = d.year == now.year ? '' : ' ${d.year}';
  return '${d.day} ${months[d.month - 1]}$year';
}

/// Чип даты: серый (впереди), оранжевый (сегодня), красный (просрочен).
Color dateChipColor(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  if (day.isAfter(t)) return AppColors.slate400;
  if (day.isAtSameMomentAs(t)) return AppColors.orange;
  return AppColors.red;
}

/// Сумма в маркере: «+10 000» / «−1 500».
String formatAmount(double v) {
  final sign = v < 0 ? '−' : '+';
  final abs = v.abs().round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  return '$sign$abs';
}

const priorityLabels = {1: 'Низкий', 2: 'Средний', 3: 'Высокий'};

/// Тема приложения.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
    ).copyWith(surface: Colors.white),
  );
  return base.copyWith(
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.header,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
