/// Дымовой UI-тест: главный экран, создание задачи через диалог,
/// свайп карточки для переноса в следующий список.
///
/// Компилирует весь UI-слой (home_screen, dialogs, task_form_dialog,
/// main с уведомлениями) и прогоняет сценарии на реальном SQLite-хранилище
/// во временной папке.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnitask_local/app_controller.dart';
import 'package:omnitask_local/models.dart';
import 'package:omnitask_local/ui/home_screen.dart';
import 'package:omnitask_local/ui/onboarding_screen.dart';
import 'package:omnitask_local/vault.dart';

// Импорт main.dart компилирует точку входа и сервис уведомлений в тесте.
// ignore: unused_import
import 'package:omnitask_local/main.dart' as app;

Future<AppController> pumpHome(WidgetTester tester, Directory dir) async {
  final controller = AppController()..openVault(dir.path);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: controller,
    child: MaterialApp(
      home: HomeScreen(onChangeVault: (_) async {}),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('Онбординг показывает выбор хранилища', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onVaultSelected: (_) async {}),
    ));
    expect(find.text('OMNITASK LOCAL'), findsOneWidget);
    expect(find.text('Выбрать папку хранилища'), findsOneWidget);
  });

  testWidgets('Создание задачи через FAB и появление карточки',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('omnitask_ui');
    addTearDown(() => dir.deleteSync(recursive: true));

    final controller = await pumpHome(tester, dir);

    // Доска «Личное» в шапке, группы списков на доске.
    expect(find.text('Личное'), findsOneWidget);
    expect(find.text('Не начато'), findsOneWidget);
    // «Готово» есть и в фильтре-сводке, и в заголовке группы.
    expect(find.text('Готово'), findsNWidgets(2));

    // Открываем редактор задачи.
    await tester.tap(find.text('Новая задача'));
    await tester.pumpAndSettle();
    expect(find.text('Создать задачу'), findsWidgets);

    await tester.enterText(
        find.widgetWithText(TextField, 'Введите название задачи'),
        'Купить молоко');
    // Кнопка сохранения — FilledButton.icon (подкласс), ищем по последнему
    // совпадению текста (заголовок диалога — первое).
    await tester.tap(find.text('Создать задачу').last);
    await tester.pumpAndSettle();

    // Карточка появилась на доске и легла в БД.
    expect(find.text('Купить молоко'), findsOneWidget);
    expect(controller.tasks.map((t) => t.title), contains('Купить молоко'));
    final reloaded = Vault(dir.path);
    expect(reloaded.listTasks(controller.activeBoardId!).map((t) => t.title),
        contains('Купить молоко'));
    reloaded.close();
  });

  testWidgets('Свайп карточки вправо переносит в следующий список',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('omnitask_ui_swipe');
    addTearDown(() => dir.deleteSync(recursive: true));

    final controller = await pumpHome(tester, dir);
    controller.createTask(VaultTask(title: 'Свайп-задача'));
    await tester.pumpAndSettle();

    final card = find.text('Свайп-задача');
    expect(card, findsOneWidget);

    // Свайп вправо на 150px (> порога 72) — задача уходит в «В работе».
    await tester.drag(card, const Offset(150, 0));
    await tester.pumpAndSettle();

    final moved =
        controller.tasks.firstWhere((t) => t.title == 'Свайп-задача');
    expect(moved.listName, 'В работе');
  });

  testWidgets('Свайп влево в «Не начато» подтверждает удаление',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('omnitask_ui_del');
    addTearDown(() => dir.deleteSync(recursive: true));

    final controller = await pumpHome(tester, dir);
    controller.createTask(VaultTask(title: 'Удаляемая'));
    await tester.pumpAndSettle();

    // Свайп влево в первом списке → диалог удаления.
    await tester.drag(find.text('Удаляемая'), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Удалить задачу?'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(controller.tasks.map((t) => t.title), isNot(contains('Удаляемая')));
  });
}
