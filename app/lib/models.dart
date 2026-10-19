/// Доменные модели Omnitask Local.
///
/// Порт функционала справочного проекта mcp-todo (без пользователей,
/// без облака): доски, списки, задачи, теги, блокировки, циклы, валюты.
library;

class VaultBoard {
  int? id;
  String name;
  String description;
  String color; // hex, BOARD_PALETTE
  int position;

  /// Валюта расчёта бюджета доски; null — валюта по умолчанию
  /// (первая в порядке списка валют).
  int? reportCurrencyId;

  VaultBoard({
    this.id,
    required this.name,
    this.description = '',
    this.color = '#0ea5e9',
    this.position = 0,
    this.reportCurrencyId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'position': position,
        'report_currency_id': reportCurrencyId,
      };

  static VaultBoard fromMap(Map<String, Object?> m) => VaultBoard(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: (m['description'] ?? '') as String,
        color: (m['color'] ?? '#0ea5e9') as String,
        position: (m['position'] ?? 0) as int,
        reportCurrencyId: m['report_currency_id'] as int?,
      );
}

class VaultList {
  int? id;
  String name;
  String color;
  int position;
  bool isDefault;
  String? kind; // 'todo' | 'progress' | 'done'

  VaultList({
    this.id,
    required this.name,
    this.color = '#64748b',
    this.position = 0,
    this.isDefault = false,
    this.kind,
  });

  bool get isDone => kind == 'done';
  bool get isProgress => kind == 'progress';

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'position': position,
        'is_default': isDefault ? 1 : 0,
        'kind': kind,
      };

  static VaultList fromMap(Map<String, Object?> m) => VaultList(
        id: m['id'] as int?,
        name: m['name'] as String,
        color: (m['color'] ?? '#64748b') as String,
        position: (m['position'] ?? 0) as int,
        isDefault: (m['is_default'] ?? 0) == 1,
        kind: m['kind'] as String?,
      );
}

class VaultTag {
  int? id;
  String name;
  String color;

  VaultTag({this.id, required this.name, this.color = '#64748b'});

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'color': color};

  static VaultTag fromMap(Map<String, Object?> m) => VaultTag(
        id: m['id'] as int?,
        name: m['name'] as String,
        color: (m['color'] ?? '#64748b') as String,
      );
}

class VaultTask {
  int? id;
  int boardId; // выставляется при создании через Vault.createTask
  String title;
  String description;
  DateTime? startDate;
  DateTime? deadline;
  int priority; // 1 низкий, 2 средний, 3 высокий
  String status; // todo | in_progress | done (производный от списка)
  double amount; // доход +, расход −
  int? currencyId;
  String listName;
  DateTime createdAt;

  // Циклическая задача.
  bool isCyclic;
  String cyclePeriod; // daily | weekly | monthly | yearly
  int cycleInterval;
  String? cycleGroupId;
  int reminderDays;
  bool cycleDormant; // вне окна напоминания (вычисляется)

  // Блокировки (вычисляются при загрузке).
  List<int> blockedBy;
  bool isBlocked;
  List<String> tags;

  VaultTask({
    this.id,
    this.boardId = 0,
    required this.title,
    this.description = '',
    this.startDate,
    this.deadline,
    this.priority = 1,
    this.status = 'todo',
    this.amount = 0,
    this.currencyId,
    this.listName = 'Входящие',
    DateTime? createdAt,
    this.isCyclic = false,
    this.cyclePeriod = 'monthly',
    this.cycleInterval = 1,
    this.cycleGroupId,
    this.reminderDays = 0,
    this.cycleDormant = false,
    List<int>? blockedBy,
    this.isBlocked = false,
    List<String>? tags,
  })  : createdAt = createdAt ?? DateTime.now(),
        blockedBy = blockedBy ?? [],
        tags = tags ?? [];

  bool get isDone => status == 'done';
  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && !isDone;

  Map<String, Object?> toMap() => {
        'id': id,
        'board_id': boardId,
        'title': title,
        'description': description,
        'start_date': startDate?.millisecondsSinceEpoch,
        'deadline': deadline?.millisecondsSinceEpoch,
        'priority': priority,
        'status': status,
        'amount': amount,
        'currency_id': currencyId,
        'list': listName,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_cyclic': isCyclic ? 1 : 0,
        'cycle_period': cyclePeriod,
        'cycle_interval': cycleInterval,
        'cycle_group_id': cycleGroupId,
        'reminder_days': reminderDays,
      };

  static VaultTask fromMap(Map<String, Object?> m) => VaultTask(
        id: m['id'] as int?,
        boardId: m['board_id'] as int,
        title: m['title'] as String,
        description: (m['description'] ?? '') as String,
        startDate: _dt(m['start_date']),
        deadline: _dt(m['deadline']),
        priority: (m['priority'] ?? 1) as int,
        status: (m['status'] ?? 'todo') as String,
        amount: ((m['amount'] ?? 0) as num).toDouble(),
        currencyId: m['currency_id'] as int?,
        listName: (m['list'] ?? 'Входящие') as String,
        createdAt: _dt(m['created_at']) ?? DateTime.now(),
        isCyclic: (m['is_cyclic'] ?? 0) == 1,
        cyclePeriod: (m['cycle_period'] ?? 'monthly') as String,
        cycleInterval: (m['cycle_interval'] ?? 1) as int,
        cycleGroupId: m['cycle_group_id'] as String?,
        reminderDays: (m['reminder_days'] ?? 0) as int,
      );

  static DateTime? _dt(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
}

class VaultCurrency {
  int? id;
  String code;
  String name;
  String symbol;
  double? rate; // стоимость 1 единицы в USD
  int position;

  VaultCurrency({
    this.id,
    required this.code,
    required this.name,
    required this.symbol,
    this.rate,
    this.position = 0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'symbol': symbol,
        'rate': rate,
        'position': position,
      };

  static VaultCurrency fromMap(Map<String, Object?> m) => VaultCurrency(
        id: m['id'] as int?,
        code: m['code'] as String,
        name: m['name'] as String,
        symbol: (m['symbol'] ?? '') as String,
        rate: (m['rate'] as num?)?.toDouble(),
        position: (m['position'] ?? 0) as int,
      );
}

class CycleLogEntry {
  int? id;
  String cycleGroupId;
  String taskTitle;
  String action; // completed | stopped
  DateTime? deadline;
  DateTime loggedAt;

  CycleLogEntry({
    this.id,
    required this.cycleGroupId,
    required this.taskTitle,
    required this.action,
    this.deadline,
    required this.loggedAt,
  });

  static CycleLogEntry fromMap(Map<String, Object?> m) => CycleLogEntry(
        id: m['id'] as int?,
        cycleGroupId: m['cycle_group_id'] as String,
        taskTitle: m['task_title'] as String,
        action: m['action'] as String,
        deadline: _dt(m['deadline']),
        loggedAt:
            _dt(m['logged_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  static DateTime? _dt(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
}

class ChangeLogEntry {
  int? id;
  int taskId;
  String field;
  String? oldValue;
  String? newValue;
  DateTime changedAt;

  ChangeLogEntry({
    this.id,
    required this.taskId,
    required this.field,
    this.oldValue,
    this.newValue,
    required this.changedAt,
  });

  static ChangeLogEntry fromMap(Map<String, Object?> m) => ChangeLogEntry(
        id: m['id'] as int?,
        taskId: m['task_id'] as int,
        field: m['field'] as String,
        oldValue: m['old_value'] as String?,
        newValue: m['new_value'] as String?,
        changedAt:
            _dt(m['changed_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  static DateTime? _dt(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
}

class Summary {
  final int total;
  final int todo;
  final int inProgress;
  final int done;
  final int overdue;
  final int planned;

  const Summary({
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.done,
    required this.overdue,
    required this.planned,
  });
}

/// Запись бюджета: одна задача с ненулевой суммой.
///
/// `amount` — исходная сумма в валюте задачи; `converted` — эквивалент
/// в валюте расчёта доски (null — курс не указан).
class BudgetEntry {
  final int taskId;
  final String title;
  final String list;
  final double amount;
  final int? currencyId;
  final String? currencyCode;
  final double? converted;

  const BudgetEntry({
    required this.taskId,
    required this.title,
    required this.list,
    required this.amount,
    this.currencyId,
    this.currencyCode,
    this.converted,
  });

  /// Задача в списке со свойством «done» (входит в ФАКТ).
  bool isDoneIn(Set<String> doneNames) => doneNames.contains(list);
}

/// Бюджет доски: итоги в валюте расчёта + записи (порт board_budget).
///
/// ПЛАН = все суммы − ФАКТ; ФАКТ = суммы в списках со свойством done;
/// ИТОГО = все суммы доски. Сумма 0 в записи не участвует.
class BudgetReport {
  final int boardId;
  final int? reportCurrencyId;
  final String? reportCurrencyCode;
  final String? reportCurrencySymbol;

  /// Есть валюта(ы) без курса — итоги неполные (UI показывает warning).
  final bool missingRate;

  final double plan;
  final double fact;
  final double total;
  final double income;
  final double expense;

  final List<BudgetEntry> entries;

  const BudgetReport({
    required this.boardId,
    this.reportCurrencyId,
    this.reportCurrencyCode,
    this.reportCurrencySymbol,
    required this.missingRate,
    required this.plan,
    required this.fact,
    required this.total,
    required this.income,
    required this.expense,
    required this.entries,
  });
}
