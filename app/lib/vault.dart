/// Слой хранения Omnitask Local: SQLite-файл `tasks.db` в папке-хранилище
/// (vault), выбранной пользователем. Полностью локально, без сети.
///
/// Порт бизнес-логики справочного проекта mcp-todo (task_service / board /
/// currency_service) в однопользовательский локальный вариант.
library;

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

/// Палитра цветов списков/тегов (PALETTE из справочного проекта).
const List<String> kPalette = [
  '#ef4444', '#f97316', '#f59e0b', '#eab308', '#84cc16', '#22c55e',
  '#10b981', '#14b8a6', '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1',
  '#8b5cf6', '#a855f7', '#d946ef', '#ec4899', '#f43f5e', '#64748b',
];

/// Палитра цветов досок.
const List<String> kBoardPalette = [
  '#38bdf8', '#0ea5e9', '#2dd4bf', '#34d399', '#a3e635', '#facc15',
  '#fb923c', '#f87171', '#fb7185', '#f472b6', '#c084fc', '#a78bfa',
  '#818cf8', '#60a5fa', '#94a3b8', '#fbbf24', '#4ade80', '#e879f9',
  '#22d3ee', '#fda4af',
];

const List<Map<String, Object>> kDefaultLists = [
  {'name': 'Не начато', 'color': '#64748b', 'position': 1, 'kind': 'todo'},
  {'name': 'В работе', 'color': '#3b82f6', 'position': 2, 'kind': 'progress'},
  {'name': 'Готово', 'color': '#22c55e', 'position': 3, 'kind': 'done'},
  {'name': 'Архив', 'color': '#8b5cf6', 'position': 4, 'kind': 'done'},
];

const List<List<String>> kDefaultCurrencies = [
  // code, name, symbol, rate
  ['USD', 'Доллар (США)', r'$', '1.0'],
  ['RUB', 'Рубли (РФ)', '₽', '0.011'],
  ['EUR', 'Евро (ЕС)', '€', '1.1'],
];

/// Бизнес-правило нарушено (сообщение — для пользователя).
class TaskError implements Exception {
  final String message;
  TaskError(this.message);
  @override
  String toString() => message;
}

class Vault {
  final String vaultPath; // путь к папке хранилища
  late final Database _db;

  Vault(this.vaultPath) {
    _db = sqlite3.open(p.join(vaultPath, 'tasks.db'));
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute('PRAGMA foreign_keys = ON;');
    _migrate();
    _seed();
  }

  void close() => _db.dispose();

  // ---------------- Схема ----------------

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS boards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        color TEXT NOT NULL DEFAULT '#0ea5e9',
        position INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS task_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        board_id INTEGER NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#64748b',
        position INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        kind TEXT,
        UNIQUE(board_id, name)
      );
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        board_id INTEGER NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#64748b',
        UNIQUE(board_id, name)
      );
      CREATE TABLE IF NOT EXISTS currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        rate REAL,
        position INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        board_id INTEGER NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        start_date INTEGER,
        deadline INTEGER,
        priority INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'todo',
        amount REAL NOT NULL DEFAULT 0,
        currency_id INTEGER REFERENCES currencies(id) ON DELETE SET NULL,
        list TEXT NOT NULL DEFAULT 'Входящие',
        created_at INTEGER NOT NULL,
        is_cyclic INTEGER NOT NULL DEFAULT 0,
        cycle_period TEXT DEFAULT 'monthly',
        cycle_interval INTEGER NOT NULL DEFAULT 1,
        cycle_group_id TEXT,
        reminder_days INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_tasks_board ON tasks(board_id);
      CREATE TABLE IF NOT EXISTS task_tags (
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (task_id, tag_id)
      );
      CREATE TABLE IF NOT EXISTS task_dependencies (
        blocker_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        blocked_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        PRIMARY KEY (blocker_id, blocked_id)
      );
      CREATE TABLE IF NOT EXISTS task_cycle_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_group_id TEXT NOT NULL,
        task_title TEXT NOT NULL,
        action TEXT NOT NULL,
        deadline INTEGER,
        logged_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS task_change_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        field TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        changed_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
  }

  void _seed() {
    if (_db.select('SELECT COUNT(*) c FROM boards').first['c'] == 0) {
      _db.execute(
        "INSERT INTO boards (name, description, color, position) "
        "VALUES ('Личное', '', '#0ea5e9', 0)",
      );
    }
    for (final board in listBoards()) {
      _ensureDefaultLists(board.id!);
    }
    if (_db.select('SELECT COUNT(*) c FROM currencies').first['c'] == 0) {
      for (var i = 0; i < kDefaultCurrencies.length; i++) {
        final c = kDefaultCurrencies[i];
        _db.execute(
          'INSERT INTO currencies (code, name, symbol, rate, position) '
          'VALUES (?, ?, ?, ?, ?)',
          [c[0], c[1], c[2], double.parse(c[3]), i],
        );
      }
    }
  }

  void _ensureDefaultLists(int boardId) {
    final existing = _db
        .select('SELECT name FROM task_lists WHERE board_id = ?', [boardId])
        .map((r) => r['name'] as String)
        .toSet();
    for (final spec in kDefaultLists) {
      if (!existing.contains(spec['name'])) {
        _db.execute(
          'INSERT INTO task_lists (board_id, name, color, position, is_default, kind) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [
            boardId,
            spec['name'],
            spec['color'],
            spec['position'],
            spec['kind'],
          ],
        );
      }
    }
  }

  // ---------------- Доски ----------------

  List<VaultBoard> listBoards() => _db
      .select('SELECT * FROM boards ORDER BY position, id')
      .map((r) => VaultBoard.fromMap(r))
      .toList();

  VaultBoard createBoard(String name, {String description = '', String? color}) {
    final pos = _db.select('SELECT COALESCE(MAX(position), -1) + 1 p FROM boards').first['p'] as int;
    _db.execute(
      'INSERT INTO boards (name, description, color, position) VALUES (?, ?, ?, ?)',
      [name, description, color ?? kBoardPalette.first, pos],
    );
    final id = _db.lastInsertRowId;
    _ensureDefaultLists(id);
    return getBoard(id)!;
  }

  VaultBoard? getBoard(int id) {
    final rows = _db.select('SELECT * FROM boards WHERE id = ?', [id]);
    return rows.isEmpty ? null : VaultBoard.fromMap(rows.first);
  }

  void updateBoard(int id, {String? name, String? description, String? color, int? position}) {
    if (name != null) {
      _db.execute('UPDATE boards SET name = ? WHERE id = ?', [name, id]);
    }
    if (description != null) {
      _db.execute(
          'UPDATE boards SET description = ? WHERE id = ?', [description, id]);
    }
    if (color != null) {
      _db.execute('UPDATE boards SET color = ? WHERE id = ?', [color, id]);
    }
    if (position != null) {
      _db.execute('UPDATE boards SET position = ? WHERE id = ?', [position, id]);
    }
  }

  void deleteBoard(int id) {
    final count = _db.select('SELECT COUNT(*) c FROM boards').first['c'] as int;
    if (count <= 1) {
      throw TaskError('Нельзя удалить последнюю доску');
    }
    _db.execute('DELETE FROM boards WHERE id = ?', [id]);
  }

  // ---------------- Списки ----------------

  List<VaultList> listLists(int boardId) => _db
      .select(
          'SELECT * FROM task_lists WHERE board_id = ? ORDER BY position, id',
          [boardId])
      .map((r) => VaultList.fromMap(r))
      .toList();

  VaultList? _findList(int boardId, String? name) {
    if (name == null || name.isEmpty) return null;
    final rows = _db.select(
      'SELECT * FROM task_lists WHERE board_id = ? AND name = ?',
      [boardId, name],
    );
    return rows.isEmpty ? null : VaultList.fromMap(rows.first);
  }

  /// (имя списка, статус) — неизвестное имя → «Не начато» доски.
  (String, String) _resolveList(int boardId, String? name) {
    var l = _findList(boardId, name);
    l ??= _findList(boardId, 'Не начато');
    if (l == null) return ('Не начато', 'todo');
    return (l.name, _statusForKind(l.kind));
  }

  static String _statusForKind(String? kind) {
    if (kind == 'done') return 'done';
    if (kind == 'progress') return 'in_progress';
    return 'todo';
  }

  VaultList createList(int boardId, String name, {String? color, String? kind}) {
    final pos = (_db
            .select(
              'SELECT COALESCE(MAX(position), 0) + 1 p FROM task_lists WHERE board_id = ?',
              [boardId],
            )
            .first['p'] as int?) ??
        1;
    _db.execute(
      'INSERT INTO task_lists (board_id, name, color, position, kind) VALUES (?, ?, ?, ?, ?)',
      [boardId, name, color ?? '#64748b', pos, kind ?? 'todo'],
    );
    final rows = _db.select('SELECT * FROM task_lists WHERE id = ?',
        [_db.lastInsertRowId]);
    return VaultList.fromMap(rows.first);
  }

  void updateList(int listId,
      {String? name, String? color, String? kind, int? position}) {
    if (name != null) {
      _db.execute('UPDATE task_lists SET name = ? WHERE id = ?', [name, listId]);
    }
    if (color != null) {
      _db.execute(
          'UPDATE task_lists SET color = ? WHERE id = ?', [color, listId]);
    }
    if (kind != null) {
      _db.execute('UPDATE task_lists SET kind = ? WHERE id = ?', [kind, listId]);
    }
    if (position != null) {
      _db.execute(
          'UPDATE task_lists SET position = ? WHERE id = ?', [position, listId]);
    }
  }

  void deleteList(int listId) {
    final row = _db.select(
      'SELECT board_id, name, kind FROM task_lists WHERE id = ?', [listId]);
    if (row.isEmpty) return;
    final boardId = row.first['board_id'] as int;
    final name = row.first['name'] as String;
    // Задачи списка переносим в «Не начато» (или первый оставшийся список).
    final fallback = _db.select(
      'SELECT name FROM task_lists WHERE board_id = ? AND id != ? '
      'ORDER BY position, id LIMIT 1',
      [boardId, listId],
    );
    if (fallback.isEmpty) {
      throw TaskError('Нельзя удалить единственный список');
    }
    final target = fallback.first['name'] as String;
    final targetKind = _db.select(
      'SELECT kind FROM task_lists WHERE board_id = ? AND name = ?',
      [boardId, target],
    ).first['kind'] as String?;
    _db.execute('UPDATE tasks SET list = ?, status = ? WHERE list = ?',
        [target, _statusForKind(targetKind), name]);
    _db.execute('DELETE FROM task_lists WHERE id = ?', [listId]);
  }

  // ---------------- Теги ----------------

  List<VaultTag> listTags(int boardId) => _db
      .select('SELECT * FROM tags WHERE board_id = ? ORDER BY name', [boardId])
      .map((r) => VaultTag.fromMap(r))
      .toList();

  /// Цвета, занятые списками доски, — тегам они не достаются.
  Set<String> _listColors(int boardId) => _db
      .select('SELECT color FROM task_lists WHERE board_id = ?', [boardId])
      .map((r) => r['color'] as String)
      .toSet();

  VaultTag _ensureTag(int boardId, String name) {
    name = name.trim();
    if (name.isEmpty) throw TaskError('Пустое имя тега');
    final rows = _db.select(
      'SELECT * FROM tags WHERE board_id = ? AND name = ?', [boardId, name]);
    if (rows.isNotEmpty) return VaultTag.fromMap(rows.first);
    final used = _db
        .select('SELECT color FROM tags WHERE board_id = ?', [boardId])
        .map((r) => r['color'] as String)
        .toSet();
    final avail = kPalette.where((c) => !_listColors(boardId).contains(c));
    String color = avail.firstWhere((c) => !used.contains(c),
        orElse: () => kPalette[used.length % kPalette.length]);
    _db.execute(
      'INSERT INTO tags (board_id, name, color) VALUES (?, ?, ?)',
      [boardId, name, color],
    );
    return VaultTag(id: _db.lastInsertRowId, name: name, color: color);
  }

  // ---------------- Задачи ----------------

  List<VaultTask> listTasks(int boardId) {
    final tasks = _db
        .select('SELECT * FROM tasks WHERE board_id = ? ORDER BY created_at, id',
            [boardId])
        .map((r) => VaultTask.fromMap(r))
        .toList();
    if (tasks.isEmpty) return tasks;

    final ids = tasks.map((t) => t.id!).toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    // Блокировки.
    final deps = _db.select(
      'SELECT blocked_id, blocker_id FROM task_dependencies '
      'WHERE blocked_id IN ($placeholders)',
      ids,
    );
    final blockersByTask = <int, List<int>>{};
    for (final r in deps) {
      blockersByTask
          .putIfAbsent(r['blocked_id'] as int, () => [])
          .add(r['blocker_id'] as int);
    }
    final allBlockers = blockersByTask.values.expand((x) => x).toSet();
    final statuses = <int, String>{};
    if (allBlockers.isNotEmpty) {
      final ph = List.filled(allBlockers.length, '?').join(',');
      for (final r in _db.select(
        'SELECT id, status FROM tasks WHERE id IN ($ph)',
        allBlockers.toList(),
      )) {
        statuses[r['id'] as int] = r['status'] as String;
      }
    }

    // Теги.
    final tagRows = _db.select(
      'SELECT tt.task_id, t.name FROM task_tags tt '
      'JOIN tags t ON t.id = tt.tag_id WHERE tt.task_id IN ($placeholders) '
      'ORDER BY t.name',
      ids,
    );
    final tagsByTask = <int, List<String>>{};
    for (final r in tagRows) {
      tagsByTask
          .putIfAbsent(r['task_id'] as int, () => [])
          .add(r['name'] as String);
    }

    final now = DateTime.now();
    for (final t in tasks) {
      t.blockedBy = blockersByTask[t.id] ?? [];
      t.isBlocked = t.blockedBy.any((b) => statuses[b] != 'done');
      t.tags = tagsByTask[t.id] ?? [];
      t.cycleDormant = _isCycleDormant(t, now);
    }
    return tasks;
  }

  bool _isCycleDormant(VaultTask t, DateTime now) {
    if (!t.isCyclic) return false;
    if (t.isBlocked) return false;
    if (t.deadline == null) return false;
    final windowStart =
        t.deadline!.subtract(Duration(days: t.reminderDays.clamp(0, 365)));
    return now.isBefore(windowStart);
  }

  VaultTask createTask(int boardId, VaultTask task, {List<String>? tags, List<int>? blockers}) {
    final (listName, status) = _resolveList(boardId, task.listName);
    task
      ..boardId = boardId
      ..listName = listName
      ..status = status;
    if (task.isCyclic && (task.cycleGroupId == null || task.cycleGroupId!.isEmpty)) {
      task.cycleGroupId = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
          task.title.hashCode.toRadixString(36);
    }
    if (task.cycleInterval < 1) task.cycleInterval = 1;
    if (task.reminderDays < 0) task.reminderDays = 0;

    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO tasks (board_id, title, description, start_date, deadline, '
        'priority, status, amount, currency_id, list, created_at, is_cyclic, '
        'cycle_period, cycle_interval, cycle_group_id, reminder_days) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          boardId, task.title, task.description,
          task.startDate?.millisecondsSinceEpoch,
          task.deadline?.millisecondsSinceEpoch,
          task.priority, task.status, task.amount, task.currencyId,
          task.listName, task.createdAt.millisecondsSinceEpoch,
          task.isCyclic ? 1 : 0, task.cyclePeriod, task.cycleInterval,
          task.cycleGroupId, task.reminderDays,
        ],
      );
      task.id = _db.lastInsertRowId;
      _setTags(task.id!, boardId, tags ?? task.tags);
      _setBlockers(task.id!, blockers ?? task.blockedBy, boardId);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    // Вычисляемые поля блокировки сразу после вставки.
    task.blockedBy = _db
        .select('SELECT blocker_id FROM task_dependencies WHERE blocked_id = ?',
            [task.id])
        .map((r) => r['blocker_id'] as int)
        .toList();
    task.isBlocked = _computeIsBlocked(task.blockedBy);
    return task;
  }

  void _setTags(int taskId, int boardId, List<String> names) {
    _db.execute('DELETE FROM task_tags WHERE task_id = ?', [taskId]);
    for (final name in names) {
      if (name.trim().isEmpty) continue;
      final tag = _ensureTag(boardId, name);
      _db.execute(
        'INSERT OR IGNORE INTO task_tags (task_id, tag_id) VALUES (?, ?)',
        [taskId, tag.id],
      );
    }
  }

  void _setBlockers(int taskId, List<int> blockerIds, int boardId) {
    _db.execute(
        'DELETE FROM task_dependencies WHERE blocked_id = ?', [taskId]);
    final seen = <int>{};
    for (final bid in blockerIds) {
      if (bid == taskId || !seen.add(bid)) continue;
      final b = _db.select(
        'SELECT board_id FROM tasks WHERE id = ?', [bid]);
      if (b.isEmpty || b.first['board_id'] != boardId) continue; // только своя доска
      _db.execute(
        'INSERT OR IGNORE INTO task_dependencies (blocker_id, blocked_id) '
        'VALUES (?, ?)',
        [bid, taskId],
      );
    }
  }

  bool _computeIsBlocked(List<int> blockerIds) {
    if (blockerIds.isEmpty) return false;
    final ph = List.filled(blockerIds.length, '?').join(',');
    final n = _db.select(
      'SELECT COUNT(*) c FROM tasks WHERE id IN ($ph) AND status != ?',
      [...blockerIds, 'done'],
    ).first['c'] as int;
    return n > 0;
  }

  /// Обновление задачи: сравнивает поля с текущими, пишет историю изменений.
  void updateTask(int taskId, VaultTask data,
      {List<String>? tags, List<int>? blockers}) {
    final cur = getTask(taskId);
    if (cur == null) throw TaskError('Задача не найдена');
    final boardId = cur.boardId;

    // Перенос в список со статусом «done» запрещён при блокировках.
    final newBlockers = blockers ?? cur.blockedBy;
    String newList = data.listName;
    String newStatus;
    if (newList == cur.listName) {
      newStatus = cur.status;
    } else {
      (newList, newStatus) = _resolveList(boardId, newList);
      if (newStatus == 'done' &&
          _computeIsBlocked(newBlockers.where((b) => b != taskId).toList())) {
        throw TaskError(
            'Невозможно выполнить задачу: есть незавершённые блокирующие задачи');
      }
    }

    final changes = <(String, String?, String?)>[];
    void track(String field, String? oldV, String? newV) {
      if (oldV != newV) changes.add((field, oldV, newV));
    }

    String? d(DateTime? v) => v?.millisecondsSinceEpoch.toString();

    if (data.title != cur.title) {
      track('title', cur.title, data.title);
      cur.title = data.title;
    }
    if (data.description != cur.description) {
      track('description', null, null); // текст не храним — как в оригинале
      cur.description = data.description;
    }
    if (data.startDate != cur.startDate) {
      track('start_date', d(cur.startDate), d(data.startDate));
      cur.startDate = data.startDate;
    }
    if (data.deadline != cur.deadline) {
      track('deadline', d(cur.deadline), d(data.deadline));
      cur.deadline = data.deadline;
    }
    if (data.priority != cur.priority) {
      track('priority', '${cur.priority}', '${data.priority}');
      cur.priority = data.priority;
    }
    if (data.amount != cur.amount) {
      track('amount', '${cur.amount}', '${data.amount}');
      cur.amount = data.amount;
    }
    if (data.currencyId != cur.currencyId) {
      cur.currencyId = data.currencyId;
    }
    if (newList != cur.listName) {
      track('list', cur.listName, newList);
      cur.listName = newList;
      cur.status = newStatus;
    }
    if (data.isCyclic != cur.isCyclic ||
        data.cyclePeriod != cur.cyclePeriod ||
        data.cycleInterval != cur.cycleInterval ||
        data.reminderDays != cur.reminderDays) {
      cur.isCyclic = data.isCyclic;
      cur.cyclePeriod = data.cyclePeriod;
      cur.cycleInterval = data.cycleInterval < 1 ? 1 : data.cycleInterval;
      cur.reminderDays = data.reminderDays < 0 ? 0 : data.reminderDays;
      if (cur.isCyclic &&
          (cur.cycleGroupId == null || cur.cycleGroupId!.isEmpty)) {
        cur.cycleGroupId =
            DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      }
    }

    _db.execute('BEGIN');
    try {
      _db.execute(
        'UPDATE tasks SET title = ?, description = ?, start_date = ?, '
        'deadline = ?, priority = ?, status = ?, amount = ?, currency_id = ?, '
        'list = ?, is_cyclic = ?, cycle_period = ?, cycle_interval = ?, '
        'cycle_group_id = ?, reminder_days = ? WHERE id = ?',
        [
          cur.title, cur.description,
          cur.startDate?.millisecondsSinceEpoch,
          cur.deadline?.millisecondsSinceEpoch,
          cur.priority, cur.status, cur.amount, cur.currencyId,
          cur.listName, cur.isCyclic ? 1 : 0, cur.cyclePeriod,
          cur.cycleInterval, cur.cycleGroupId, cur.reminderDays, taskId,
        ],
      );
      if (tags != null) _setTags(taskId, boardId, tags);
      if (blockers != null) _setBlockers(taskId, blockers, boardId);
      for (final (field, oldV, newV) in changes) {
        _db.execute(
          'INSERT INTO task_change_logs (task_id, field, old_value, new_value, changed_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [taskId, field, oldV, newV, DateTime.now().millisecondsSinceEpoch],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  VaultTask? getTask(int id) {
    final rows = _db.select('SELECT * FROM tasks WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final t = VaultTask.fromMap(rows.first);
    t.tags = _db
        .select('SELECT t.name FROM task_tags tt JOIN tags t ON t.id = tt.tag_id '
            'WHERE tt.task_id = ? ORDER BY t.name', [id])
        .map((r) => r['name'] as String)
        .toList();
    t.blockedBy = _db
        .select(
            'SELECT blocker_id FROM task_dependencies WHERE blocked_id = ?', [id])
        .map((r) => r['blocker_id'] as int)
        .toList();
    t.isBlocked = _computeIsBlocked(t.blockedBy);
    return t;
  }

  void deleteTask(int id) {
    _db.execute('DELETE FROM tasks WHERE id = ?', [id]);
  }

  /// Смена списка задачи (свайп/перетаскивание).
  void setTaskList(int taskId, String listName) {
    final t = getTask(taskId);
    if (t == null) return;
    final (name, status) = _resolveList(t.boardId, listName);
    if (status == 'done' && t.isBlocked) {
      throw TaskError('Сначала выполните блокирующие задачи');
    }
    if (name != t.listName) {
      _db.execute(
        'INSERT INTO task_change_logs (task_id, field, old_value, new_value, changed_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [taskId, 'list', t.listName, name, DateTime.now().millisecondsSinceEpoch],
      );
    }
    _db.execute('UPDATE tasks SET list = ?, status = ? WHERE id = ?',
        [name, status, taskId]);
  }

  // ---------------- Циклические задачи ----------------

  DateTime _advanceDeadline(DateTime dt, String period, int interval) {
    interval = interval < 1 ? 1 : interval;
    switch (period) {
      case 'daily':
        return dt.add(Duration(days: interval));
      case 'weekly':
        return dt.add(Duration(days: 7 * interval));
      case 'monthly':
        final total = dt.month - 1 + interval;
        final year = dt.year + total ~/ 12;
        final month = total % 12 + 1;
        const ml = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        final isLeap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
        final dim = month == 2 ? (isLeap ? 29 : 28) : ml[month - 1];
        return DateTime(year, month, dt.day.clamp(1, dim), dt.hour, dt.minute);
      case 'yearly':
        final year = dt.year + interval;
        final isLeap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
        var day = dt.day;
        if (dt.month == 2 && day > 28) day = isLeap ? 29 : 28;
        return DateTime(year, dt.month, day, dt.hour, dt.minute);
      default:
        return dt.add(Duration(days: interval));
    }
  }

  /// Выполнить циклическую задачу: создать следующую итерацию, записать
  /// историю, удалить текущую. Возвращает новую задачу.
  VaultTask completeCycle(int taskId) {
    final t = getTask(taskId);
    if (t == null || !t.isCyclic) throw TaskError('Задача не циклическая');
    final next = VaultTask(
      boardId: t.boardId,
      title: t.title,
      description: t.description,
      startDate: t.startDate,
      deadline:
          t.deadline == null ? null : _advanceDeadline(t.deadline!, t.cyclePeriod, t.cycleInterval),
      priority: t.priority,
      amount: t.amount,
      currencyId: t.currencyId,
      isCyclic: true,
      cyclePeriod: t.cyclePeriod,
      cycleInterval: t.cycleInterval,
      cycleGroupId: t.cycleGroupId,
      reminderDays: t.reminderDays,
      tags: List<String>.from(t.tags),
    );
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO task_cycle_logs (cycle_group_id, task_title, action, deadline, logged_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          t.cycleGroupId, t.title, 'completed',
          t.deadline?.millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    final created = createTask(t.boardId, next, tags: t.tags);
    deleteTask(taskId);
    return created;
  }

  /// Пропустить цикл: сдвинуть дедлайн без записи в историю.
  void skipCycle(int taskId) {
    final t = getTask(taskId);
    if (t == null || !t.isCyclic) throw TaskError('Задача не циклическая');
    if (t.deadline == null) return;
    final next = _advanceDeadline(t.deadline!, t.cyclePeriod, t.cycleInterval);
    _db.execute('UPDATE tasks SET deadline = ? WHERE id = ?',
        [next.millisecondsSinceEpoch, taskId]);
  }

  /// Остановить цикл: задача перестаёт быть циклической, пишется история.
  void stopCycle(int taskId) {
    final t = getTask(taskId);
    if (t == null || !t.isCyclic) throw TaskError('Задача не циклическая');
    _db.execute(
      'INSERT INTO task_cycle_logs (cycle_group_id, task_title, action, deadline, logged_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        t.cycleGroupId, t.title, 'stopped',
        t.deadline?.millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    _db.execute('UPDATE tasks SET is_cyclic = 0 WHERE id = ?', [taskId]);
  }

  List<CycleLogEntry> cycleHistory(String? groupId) {
    if (groupId == null || groupId.isEmpty) return [];
    return _db
        .select(
            'SELECT * FROM task_cycle_logs WHERE cycle_group_id = ? ORDER BY logged_at DESC',
            [groupId])
        .map((r) => CycleLogEntry.fromMap(r))
        .toList();
  }

  List<ChangeLogEntry> changeHistory(int taskId) => _db
      .select(
          'SELECT * FROM task_change_logs WHERE task_id = ? ORDER BY changed_at, id',
          [taskId])
      .map((r) => ChangeLogEntry.fromMap(r))
      .toList();

  // ---------------- Сводка ----------------

  Summary summary(int boardId) {
    final tasks = listTasks(boardId);
    final active =
        tasks.where((t) => !t.cycleDormant).toList();
    final now = DateTime.now();
    return Summary(
      total: active.length,
      todo: active.where((t) => t.status == 'todo').length,
      inProgress: active.where((t) => t.status == 'in_progress').length,
      done: tasks.where((t) => t.status == 'done').length,
      overdue: active
          .where((t) =>
              t.deadline != null && t.deadline!.isBefore(now) && !t.isDone)
          .length,
      planned: tasks.where((t) => t.isCyclic).length,
    );
  }

  // ---------------- Валюты ----------------

  List<VaultCurrency> listCurrencies() => _db
      .select('SELECT * FROM currencies ORDER BY position, id')
      .map((r) => VaultCurrency.fromMap(r))
      .toList();

  VaultCurrency? getCurrency(int? id) {
    if (id == null) return null;
    final rows = _db.select('SELECT * FROM currencies WHERE id = ?', [id]);
    return rows.isEmpty ? null : VaultCurrency.fromMap(rows.first);
  }

  VaultCurrency createCurrency(String code, String name, String symbol, double? rate) {
    code = code.trim().toUpperCase();
    if (code.isEmpty || code.length > 10 || !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      throw TaskError('Код валюты: 1–10 латинских букв/цифр (например RUB)');
    }
    if (_db.select('SELECT 1 FROM currencies WHERE code = ?', [code]).isNotEmpty) {
      throw TaskError('Валюта с кодом $code уже существует');
    }
    final pos = (_db.select('SELECT COALESCE(MAX(position), -1) + 1 p FROM currencies')
            .first['p'] as int?) ??
        0;
    _db.execute(
      'INSERT INTO currencies (code, name, symbol, rate, position) VALUES (?, ?, ?, ?, ?)',
      [code, name.isEmpty ? code : name, symbol.isEmpty ? code : symbol, rate, pos],
    );
    return getCurrency(_db.lastInsertRowId)!;
  }

  void updateCurrency(int id, {String? name, String? symbol, double? rate}) {
    if (name != null) {
      _db.execute('UPDATE currencies SET name = ? WHERE id = ?', [name, id]);
    }
    if (symbol != null) {
      _db.execute('UPDATE currencies SET symbol = ? WHERE id = ?', [symbol, id]);
    }
    if (rate != null) {
      _db.execute('UPDATE currencies SET rate = ? WHERE id = ?', [rate, id]);
    }
  }

  void deleteCurrency(int id) {
    _db.execute('UPDATE tasks SET currency_id = NULL WHERE currency_id = ?', [id]);
    _db.execute('DELETE FROM currencies WHERE id = ?', [id]);
    // Уплотняем позиции.
    final rows = _db.select('SELECT id FROM currencies ORDER BY position, id');
    for (var i = 0; i < rows.length; i++) {
      _db.execute('UPDATE currencies SET position = ? WHERE id = ?',
          [i, rows.first['id']]);
    }
  }

  // ---------------- Настройки ----------------

  String? getSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  void setSetting(String key, String value) {
    _db.execute(
        'INSERT INTO settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value]);
  }
}
