/// Состояние приложения: единственный ChangeNotifier поверх Vault.
///
/// Держит открытую доску, её списки/теги/задачи/сводку, активные фильтры.
/// Все бизнес-операции идут через Vault; ошибки TaskError показываются
/// вызывающему коду (UI превращает их в SnackBar).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' hide Summary;

import 'models.dart';
import 'vault.dart';

/// Фильтры сводки (как в справочном проекте).
enum TaskFilter { all, todo, inProgress, done, overdue, planned }

class AppController extends ChangeNotifier {
  late Vault _vault;
  Vault get vault => _vault;

  List<VaultBoard> boards = [];
  int? activeBoardId;

  List<VaultList> lists = [];
  List<VaultTag> tags = [];
  List<VaultTask> tasks = [];
  Summary? summary;

  TaskFilter activeFilter = TaskFilter.all;
  int? activeTagId;

  /// Уведомления о дедлайнах включены.
  bool notificationsEnabled = true;

  Timer? _refreshDebounce;

  bool get isReady => activeBoardId != null;
  VaultBoard? get activeBoard {
    for (final b in boards) {
      if (b.id == activeBoardId) return b;
    }
    return boards.isEmpty ? null : boards.first;
  }

  // ---------------- Жизненный цикл ----------------

  /// Открыть хранилище по выбранному пути.
  void openVault(String vaultPath) {
    _vault = Vault(vaultPath);
    boards = _vault.listBoards();
    notificationsEnabled = _vault.getSetting('notifications') != 'off';

    // Активная доска из прошлой сессии.
    final stored = _vault.getSetting('active_board');
    var id = stored != null ? int.tryParse(stored) : null;
    if (id == null || !boards.any((b) => b.id == id)) {
      id = boards.first.id;
    }
    activeBoardId = id;
    _reloadBoard();
  }

  void closeVault() {
    _refreshDebounce?.cancel();
    _vault.close();
  }

  /// Смена активной доски.
  void switchBoard(int boardId) {
    activeBoardId = boardId;
    _vault.setSetting('active_board', '$boardId');
    activeFilter = TaskFilter.all;
    activeTagId = null;
    _reloadBoard();
    notifyListeners();
  }

  void _reloadBoard() {
    final id = activeBoardId;
    if (id == null) return;
    lists = _vault.listLists(id);
    tags = _vault.listTags(id);
    tasks = _vault.listTasks(id);
    summary = _vault.summary(id);
  }

  /// Перечитать данные доски (после любой операции).
  void refresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 40), () {
      _reloadBoard();
      notifyListeners();
    });
  }

  // ---------------- Фильтры ----------------

  void setFilter(TaskFilter f) {
    activeFilter = f;
    notifyListeners();
  }

  void toggleTag(int? tagId) {
    activeTagId = activeTagId == tagId ? null : tagId;
    notifyListeners();
  }

  /// Задачи, видимые на доске с учётом фильтра и тега
  /// (порт filterTasks из Board.jsx).
  List<VaultTask> get visibleTasks {
    Iterable<VaultTask> filtered = tasks;

    String kindOf(String name) {
      for (final l in lists) {
        if (l.name == name) return l.kind ?? 'todo';
      }
      return 'todo';
    }

    switch (activeFilter) {
      case TaskFilter.all:
        filtered = filtered.where((t) => !t.cycleDormant);
        break;
      case TaskFilter.todo:
        filtered = filtered.where(
            (t) => kindOf(t.listName) == 'todo' && !t.cycleDormant);
        break;
      case TaskFilter.inProgress:
        filtered = filtered.where(
            (t) => kindOf(t.listName) == 'progress' && !t.cycleDormant);
        break;
      case TaskFilter.done:
        filtered = filtered.where((t) => kindOf(t.listName) == 'done');
        break;
      case TaskFilter.overdue:
        final now = DateTime.now();
        filtered = filtered.where((t) =>
            t.deadline != null &&
            t.deadline!.isBefore(now) &&
            !t.isDone &&
            !t.cycleDormant);
        break;
      case TaskFilter.planned:
        filtered = filtered.where((t) => t.isCyclic);
        break;
    }

    if (activeTagId != null) {
      final tag = tags.where((t) => t.id == activeTagId).firstOrNull;
      if (tag != null) {
        filtered = filtered.where((t) => t.tags.contains(tag.name));
      }
    }

    // Сортировка по дедлайну (без дедлайна — в конец).
    final list = filtered.toList()
      ..sort((a, b) {
        final ad = a.deadline ?? DateTime(9999, 12, 31);
        final bd = b.deadline ?? DateTime(9999, 12, 31);
        return ad.compareTo(bd);
      });
    return list;
  }

  // ---------------- Доски ----------------

  void createBoard(String name, String description, String color) {
    final b = _vault.createBoard(name, description: description, color: color);
    boards = _vault.listBoards();
    switchBoard(b.id!);
  }

  void updateBoard(int id,
      {String? name, String? description, String? color}) {
    _vault.updateBoard(id,
        name: name, description: description, color: color);
    boards = _vault.listBoards();
    refresh();
  }

  void deleteBoard(int id) {
    _vault.deleteBoard(id);
    boards = _vault.listBoards();
    activeBoardId = boards.first.id;
    _vault.setSetting('active_board', '$activeBoardId');
    _reloadBoard();
    notifyListeners();
  }

  // ---------------- Списки ----------------

  VaultList addList(String name, {String? color, String? kind}) {
    final l = _vault.createList(activeBoardId!, name,
        color: color, kind: kind);
    refresh();
    return l;
  }

  void updateList(int id,
      {String? name, String? color, String? kind}) {
    _vault.updateList(id, name: name, color: color, kind: kind);
    refresh();
  }

  void deleteList(int id) {
    _vault.deleteList(id);
    refresh();
  }

  /// Смена списка задачи (свайп). Бросает TaskError при блокировке.
  void setTaskList(int taskId, String listName) {
    _vault.setTaskList(taskId, listName);
    refresh();
  }

  // ---------------- Задачи ----------------

  VaultTask createTask(VaultTask task,
      {List<String>? tags, List<int>? blockers}) {
    final t = _vault.createTask(activeBoardId!, task,
        tags: tags, blockers: blockers);
    refresh();
    return t;
  }

  void updateTask(int taskId, VaultTask data,
      {List<String>? tags, List<int>? blockers}) {
    _vault.updateTask(taskId, data, tags: tags, blockers: blockers);
    refresh();
  }

  void deleteTask(int id) {
    _vault.deleteTask(id);
    refresh();
  }

  // ---------------- Циклы ----------------

  void completeCycle(int taskId) {
    _vault.completeCycle(taskId);
    refresh();
  }

  void skipCycle(int taskId) {
    _vault.skipCycle(taskId);
    refresh();
  }

  void stopCycle(int taskId) {
    _vault.stopCycle(taskId);
    refresh();
  }

  // ---------------- Валюты ----------------

  List<VaultCurrency> get currencies => _vault.listCurrencies();

  /// Бюджет активной доски (пересчитывается на лету).
  BudgetReport get budget => _vault.boardBudget(activeBoardId!);

  /// Смена валюты расчёта бюджета доски (null — валюта по умолчанию).
  void setReportCurrency(int? currencyId) {
    final id = activeBoardId;
    if (id == null) return;
    _vault.updateBoard(id,
        clearReportCurrency: currencyId == null,
        reportCurrencyId: currencyId);
    boards = _vault.listBoards();
    notifyListeners();
  }

  /// Сохранить порядок валют (влияет на валюту по умолчанию).
  void reorderCurrencies(List<int> orderedIds) {
    _vault.reorderCurrencies(orderedIds);
    notifyListeners();
  }

  // ---------------- Настройки ----------------

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    _vault.setSetting('notifications', value ? 'on' : 'off');
    notifyListeners();
  }

  /// Задачи для уведомлений: дедлайн в течение 24 часов или просрочен.
  /// Если уведомления выключены в настройках — пустой список.
  List<VaultTask> tasksNeedingReminder() {
    if (!notificationsEnabled) return const [];
    final now = DateTime.now();
    final soon = now.add(const Duration(hours: 24));
    return tasks.where((t) {
      if (t.isDone || t.deadline == null || t.cycleDormant) return false;
      return t.deadline!.isBefore(soon);
    }).toList();
  }
}
