/// Тесты бюджета: итоги, конвертация валют, missing rate,
/// валюта расчёта доски, порядок и валидация валют.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitask_local/models.dart';
import 'package:omnitask_local/vault.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late int boardId;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('omnitask_budget_test');
    vault = Vault(dir.path);
    boardId = vault.listBoards().first.id!;
  });

  tearDown(() {
    vault.close();
    dir.deleteSync(recursive: true);
  });

  group('Бюджет доски', () {
    test('план/факт/итого по свойствам списков', () {
      // Списки доски: Не начато (todo), В работе (progress),
      // Готово (done), Архив (done).
      vault.createTask(
          boardId,
          VaultTask(
              title: 'Доход', amount: 1000, listName: 'Не начато'));
      vault.createTask(
          boardId,
          VaultTask(title: 'Расход', amount: -300, listName: 'В работе'));
      vault.createTask(
          boardId,
          VaultTask(title: 'Готово+', amount: 500, listName: 'Готово'));
      vault.createTask(
          boardId,
          VaultTask(
              title: 'Без суммы', amount: 0, listName: 'Не начато'));

      final b = vault.boardBudget(boardId);
      expect(b.total, 1200); // 1000 − 300 + 500
      expect(b.fact, 500); // только done-список
      expect(b.plan, 700); // total − fact
      expect(b.income, 1500); // 1000 + 500
      expect(b.expense, -300);
      expect(b.entries.length, 3); // нулевая сумма не участвует
      expect(b.missingRate, isFalse);
      expect(b.reportCurrencyCode, 'USD'); // валюта по умолчанию — первая
    });

    test('конвертация между валютами по курсам', () {
      final rub = vault.listCurrencies().firstWhere((c) => c.code == 'RUB');
      // RUB-задача: −11 000 ₽ × 0.011 = −121 USD.
      vault.createTask(
          boardId,
          VaultTask(
              title: 'RUB-трата',
              amount: -11000,
              currencyId: rub.id,
              listName: 'Не начато'));
      // USD-задача без валюты (NULL = валюта по умолчанию USD).
      vault.createTask(
          boardId,
          VaultTask(
              title: 'USD-доход', amount: 100, listName: 'Не начато'));

      final b = vault.boardBudget(boardId);
      // Итоги в USD: −121 (из RUB) + 100 = −21.
      expect(b.total, -21);
      final rubEntry = b.entries.firstWhere((e) => e.title == 'RUB-трата');
      expect(rubEntry.currencyCode, 'RUB');
      expect(rubEntry.converted, -121);
      expect(b.missingRate, isFalse);
    });

    test('валюта без курса даёт missingRate и null в записи', () {
      final cur = vault.createCurrency('XXX', 'Икс', 'X', null);
      vault.createTask(
          boardId,
          VaultTask(
              title: 'Без курса',
              amount: -100,
              currencyId: cur.id,
              listName: 'Не начато'));

      final b = vault.boardBudget(boardId);
      expect(b.missingRate, isTrue);
      final entry = b.entries.single;
      expect(entry.converted, isNull);
      expect(entry.currencyCode, 'XXX');
      // null-конверсия не вносит вклад в итоги.
      expect(b.total, 0);
    });

    test('валюта расчёта доски: смена пересчитывает итоги', () {
      final eur = vault.listCurrencies().firstWhere((c) => c.code == 'EUR');
      vault.createTask(
          boardId,
          VaultTask(
              title: 'EUR', amount: -110, listName: 'Не начато'));

      // По умолчанию (USD): −110 USD.
      expect(vault.boardBudget(boardId).total, -110);

      // Валюта расчёта EUR: −110 USD / 1.1 = −100 EUR.
      vault.updateBoard(boardId, reportCurrencyId: eur.id);
      final b = vault.boardBudget(boardId);
      expect(b.total, -100);
      expect(b.reportCurrencyCode, 'EUR');
      expect(vault.getBoard(boardId)!.reportCurrencyId, eur.id);

      // Сброс в дефолтную валюту.
      vault.updateBoard(boardId, clearReportCurrency: true);
      expect(vault.boardBudget(boardId).total, -110);
    });

    test('удаление валюты расчёта сбрасывает валюту доски', () {
      final eur = vault.listCurrencies().firstWhere((c) => c.code == 'EUR');
      vault.updateBoard(boardId, reportCurrencyId: eur.id);
      vault.deleteCurrency(eur.id!);
      expect(vault.getBoard(boardId)!.reportCurrencyId, isNull);
    });
  });

  group('Валюты', () {
    test('валидация курса', () {
      expect(() => vault.createCurrency('BAD', '', '', -1),
          throwsA(isA<TaskError>()));
      expect(() => vault.createCurrency('BAD', '', '', 0),
          throwsA(isA<TaskError>()));
      expect(() => vault.createCurrency('BAD', '', '', 2e9),
          throwsA(isA<TaskError>()));
      final ok = vault.createCurrency('GOOD', '', '', 1.5);
      expect(() => vault.updateCurrency(ok.id!, rate: -0.1),
          throwsA(isA<TaskError>()));
    });

    test('валюта по умолчанию — первая в порядке', () {
      expect(vault.defaultCurrency()!.code, 'USD');
      final ids = vault.listCurrencies().map((c) => c.id!).toList().reversed
          .toList();
      vault.reorderCurrencies(ids);
      expect(vault.defaultCurrency()!.code, 'EUR');
      expect(vault.listCurrencies().map((c) => c.code).toList(),
          ['EUR', 'RUB', 'USD']);
    });

    test('reorder сохраняет относительный порядок пропущенных', () {
      final cs = vault.listCurrencies();
      // Указываем только RUB — остальные (USD, EUR) идут после, в своём порядке.
      final rub = cs.firstWhere((c) => c.code == 'RUB');
      vault.reorderCurrencies([rub.id!]);
      expect(vault.listCurrencies().map((c) => c.code).toList(),
          ['RUB', 'USD', 'EUR']);
    });

    test('лимит 50 валют', () {
      final seed = vault.listCurrencies().length; // 3 из сида
      for (var i = seed; i < Vault.maxCurrencies; i++) {
        vault.createCurrency('C$i', '', '', 1.0);
      }
      expect(vault.listCurrencies().length, Vault.maxCurrencies);
      expect(() => vault.createCurrency('EXTRA', '', '', 1.0),
          throwsA(isA<TaskError>()));
    });
  });
}
