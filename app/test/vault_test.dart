import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitask_local/models.dart';
import 'package:omnitask_local/vault.dart';

void main() {
  late Directory dir;
  late Vault vault;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('omnitask_test');
    vault = Vault(dir.path);
  });

  tearDown(() {
    vault.close();
    dir.deleteSync(recursive: true);
  });

  group('Инициализация хранилища', () {
    test('создаёт tasks.db, доску, списки и валюты по умолчанию', () {
      expect(File('${dir.path}/tasks.db').existsSync(), isTrue);
      expect(vault.listBoards().length, 1);
      expect(vault.listBoards().first.name, 'Личное');
      final lists = vault.listLists(vault.listBoards().first.id!);
      expect(lists.map((l) => l.name),
          containsAll(['Не начато', 'В работе', 'Готово', 'Архив']));
      final currencies = vault.listCurrencies();
      expect(currencies.map((c) => c.code), ['USD', 'RUB', 'EUR']);
    });
  });

  group('Задачи: CRUD', () {
    late int boardId;
    setUp(() => boardId = vault.listBoards().first.id!);

    test('создание и чтение', () {
      final t = vault.createTask(boardId,
        VaultTask(
          title: 'Тест',
          description: 'Описание',
          deadline: DateTime(2026, 3, 1),
          priority: 3,
          amount: -1500,
        ),
        tags: ['дом', 'срочно'],
      );
      final loaded = vault.getTask(t.id!)!;
      expect(loaded.title, 'Тест');
      expect(loaded.priority, 3);
      expect(loaded.amount, -1500);
      expect(loaded.deadline, DateTime(2026, 3, 1));
      expect(loaded.tags, ['дом', 'срочно']);
      expect(loaded.status, 'todo');
    });

    test('обновление пишет историю изменений', () {
      final t = vault.createTask(boardId,
        VaultTask(title: 'A', deadline: DateTime(2026, 1, 10), priority: 1),
      );
      vault.updateTask(
        t.id!,
        VaultTask(title: 'A', deadline: DateTime(2026, 2, 20), priority: 3),
      );
      final log = vault.changeHistory(t.id!);
      final fields = log.map((c) => c.field).toSet();
      expect(fields, containsAll(['deadline', 'priority']));
    });

    test('удаление', () {
      final t = vault.createTask(boardId, VaultTask(title: 'X'));
      vault.deleteTask(t.id!);
      expect(vault.getTask(t.id!), isNull);
    });
  });

  group('Блокирующие задачи', () {
    late int boardId;
    setUp(() => boardId = vault.listBoards().first.id!);

    test('нельзя завершить заблокированную задачу', () {
      final b = vault.createTask(boardId, VaultTask(title: 'Блокер'));
      final t = vault.createTask(boardId, VaultTask(title: 'Основная'),
          blockers: [b.id!]);
      expect(t.isBlocked, isTrue);
      expect(
        () => vault.setTaskList(t.id!, 'Готово'),
        throwsA(isA<TaskError>()),
      );
    });

    test('после выполнения блокера задача завершается', () {
      final b = vault.createTask(boardId, VaultTask(title: 'Блокер'));
      final t = vault.createTask(boardId, VaultTask(title: 'Основная'),
          blockers: [b.id!]);
      vault.setTaskList(b.id!, 'Готово');
      vault.setTaskList(t.id!, 'Готово');
      expect(vault.getTask(t.id!)!.status, 'done');
    });
  });

  group('Циклические задачи', () {
    late int boardId;
    setUp(() => boardId = vault.listBoards().first.id!);

    test('выполнение создаёт следующую итерацию и пишет историю', () {
      final t = vault.createTask(boardId,
        VaultTask(
          title: 'Оплата',
          isCyclic: true,
          cyclePeriod: 'monthly',
          cycleInterval: 1,
          deadline: DateTime(2026, 1, 31),
        ),
      );
      final next = vault.completeCycle(t.id!);
      expect(vault.getTask(t.id!), isNull);
      expect(next.deadline, DateTime(2026, 2, 28));
      expect(next.isCyclic, isTrue);
      expect(next.cycleGroupId, t.cycleGroupId);
      final history = vault.cycleHistory(t.cycleGroupId);
      expect(history.length, 1);
      expect(history.first.action, 'completed');
    });

    test('skip сдвигает дедлайн без истории', () {
      final t = vault.createTask(boardId,
        VaultTask(
          title: 'Полив',
          isCyclic: true,
          cyclePeriod: 'daily',
          deadline: DateTime(2026, 1, 1),
        ),
      );
      vault.skipCycle(t.id!);
      expect(vault.getTask(t.id!)!.deadline, DateTime(2026, 1, 2));
      expect(vault.cycleHistory(t.cycleGroupId), isEmpty);
    });

    test('stop останавливает цикл и пишет историю', () {
      final t = vault.createTask(boardId,
        VaultTask(title: 'Д', isCyclic: true, cyclePeriod: 'weekly'),
      );
      vault.stopCycle(t.id!);
      final loaded = vault.getTask(t.id!)!;
      expect(loaded.isCyclic, isFalse);
      expect(vault.cycleHistory(loaded.cycleGroupId).first.action, 'stopped');
    });

    test('monthly с 31 января → 28 февраля (невисокосный год)', () {
      final t = vault.createTask(boardId,
        VaultTask(
          title: 'X',
          isCyclic: true,
          cyclePeriod: 'monthly',
          deadline: DateTime(2027, 1, 31),
        ),
      );
      final next = vault.completeCycle(t.id!);
      expect(next.deadline, DateTime(2027, 2, 28));
    });
  });

  group('Доски и списки', () {
    test('нельзя удалить последнюю доску', () {
      final b = vault.listBoards().first;
      expect(() => vault.deleteBoard(b.id!), throwsA(isA<TaskError>()));
    });

    test('создание доски даёт ей списки по умолчанию', () {
      final b = vault.createBoard('Работа');
      expect(vault.listLists(b.id!).length, 4);
    });

    test('удаление списка переносит задачи в первый оставшийся', () {
      final b = vault.listBoards().first;
      final myListObj = vault.createList(b.id!, "Мой список");
      final myList = myListObj;
      final t = vault.createTask(b.id!, VaultTask(title: 'Y'))
        ..listName = myList.name;
      vault.updateTask(t.id!, VaultTask(title: 'Y')..listName = myList.name);
      vault.deleteList(myList.id!);
      expect(vault.getTask(t.id!)!.listName, isNot(myList.name));
    });
  });

  group('Сводка', () {
    test('считает статусы и просрочку', () {
      final b = vault.listBoards().first;
      vault.createTask(b.id!, VaultTask(title: 'a'),
          );
      vault.createTask(b.id!, VaultTask(title: 'b', deadline: DateTime(2020, 1, 1)));
      final done = vault.createTask(b.id!, VaultTask(title: 'c'));
      vault.setTaskList(done.id!, 'Готово');
      final s = vault.summary(b.id!);
      expect(s.total, 3);
      expect(s.todo, 2);
      expect(s.done, 1);
      expect(s.overdue, 1);
    });

    test('дремлющие циклические не входят в total, но в planned', () {
      final b = vault.listBoards().first;
      vault.createTask(b.id!, VaultTask(
          title: 'дремлющая',
          isCyclic: true,
          cyclePeriod: 'yearly',
          reminderDays: 1,
          deadline: DateTime.now().add(const Duration(days: 100)),
        ),
      );
      vault.createTask(b.id!, VaultTask(title: 'обычная'));
      final s = vault.summary(b.id!);
      expect(s.total, 1);
      expect(s.planned, 1);
    });
  });

  group('Валюты', () {
    test('создание с уникальным кодом', () {
      final c = vault.createCurrency('GBP', 'Фунт', '£', 1.27);
      expect(c.code, 'GBP');
      expect(() => vault.createCurrency('GBP', 'X', 'x', 1.0),
          throwsA(isA<TaskError>()));
    });

    test('удаление валюты обнуляет ссылки в задачах', () {
      final c = vault.createCurrency('JPY', 'Иена', '¥', 0.0068);
      final b = vault.listBoards().first.id!;
      final t = vault.createTask(b, VaultTask(title: 'z', amount: 100, currencyId: c.id));
      vault.deleteCurrency(c.id!);
      expect(vault.getTask(t.id!)!.currencyId, isNull);
    });
  });

  group('Постоянство', () {
    test('данные читаются после повторного открытия', () {
      final b = vault.listBoards().first.id!;
      vault.createTask(b, VaultTask(title: 'persist'));
      vault.close();
      final vault2 = Vault(dir.path);
      expect(
        vault2.listTasks(b).map((t) => t.title),
        contains('persist'),
      );
      vault2.close();
    });
  });
}
