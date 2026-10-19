/// Карточка задачи — порт TaskCard.jsx из справочного проекта.
///
/// Свайп вправо → следующий список (в последнем — удаление);
/// свайп влево → предыдущий список (в первом — удаление).
/// Под карточкой появляется цветная подложка с именем целевого списка.
/// Тап — редактор; кнопки цикла для циклических задач.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../vault.dart';
import '../app_controller.dart';
import 'theme.dart';
import 'task_form_dialog.dart';

const _swipeThreshold = 72.0;
const _maxDrag = 113.0;
const _clickSlop = 8.0;

class TaskCard extends StatefulWidget {
  final VaultTask task;
  final AppController controller;

  const TaskCard({super.key, required this.task, required this.controller});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  double _dragX = 0;
  bool _dragging = false;

  VaultList? _listByName(String name) {
    for (final l in widget.controller.lists) {
      if (l.name == name) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final lists = widget.controller.lists;
    final ordered = [...lists]..sort((a, b) => a.position.compareTo(b.position));
    final idx = ordered.indexWhere((l) => l.name == task.listName);
    final nextList = idx >= 0 && idx < ordered.length - 1 ? ordered[idx + 1] : null;
    final prevList = idx > 0 ? ordered[idx - 1] : null;
    final isFirst = idx <= 0;
    final isLast = idx < 0 || idx == ordered.length - 1;
    final isDone = idx >= 0 && ordered[idx].isDone;

    final doneListName = ordered
            .where((l) => l.isDone && l.name != 'Архив')
            .followedBy(ordered.where((l) => l.isDone))
            .firstOrNull
            ?.name ??
        'Готово';

    // Блокирующие задачи с их состоянием.
    final blockers = task.blockedBy.map((id) {
      final bt = widget.controller.tasks
          .where((t) => t.id == id)
          .firstOrNull;
      final bList = bt != null ? _listByName(bt.listName) : null;
      return BlockerInfo(
        id: id,
        title: bt?.title ?? '#$id',
        isDone: bList?.isDone ?? false,
      );
    }).toList();

    final faded = task.cycleDormant || isDone;

    return Column(
      children: [
        Stack(
          children: [
            // Подложка под сдвигающейся карточкой.
            if (_dragX.abs() > 0) _buildUnderlay(nextList, prevList, isFirst, isLast),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _dragging = true;
                  _dragX = (_dragX + d.delta.dx).clamp(-_maxDrag, _maxDrag);
                });
              },
              onHorizontalDragEnd: (_) {
                final dx = _dragX;
                setState(() {
                  _dragging = false;
                  _dragX = 0;
                });
                if (dx.abs() < _clickSlop) return;
                if (dx > _swipeThreshold) {
                  if (isLast) {
                    _confirmDelete();
                  } else if (nextList != null) {
                    _moveTo(nextList);
                  }
                } else if (dx < -_swipeThreshold) {
                  if (isFirst) {
                    _confirmDelete();
                  } else if (prevList != null) {
                    _moveTo(prevList);
                  }
                }
              },
              onHorizontalDragCancel: () =>
                  setState(() { _dragging = false; _dragX = 0; }),
              onTap: () {
                if (!_dragging && _dragX.abs() < _clickSlop) {
                  _openEditor();
                }
              },
              child: Transform.translate(
                offset: Offset(_dragX, 0),
                child: Opacity(
                  opacity: faded ? 0.6 : 1,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(task),
                        const SizedBox(height: 6),
                        _buildDateRow(task),
                        if (task.tags.isNotEmpty || blockers.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _buildTagsAndBlockers(task, blockers),
                        ],
                        if (task.isCyclic) ...[
                          const SizedBox(height: 8),
                          _buildCycleControls(task, doneListName),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Строка заголовка: точка приоритета, название, сумма ----------

  Widget _buildTitleRow(VaultTask task) {
    return Row(
      children: [
        Tooltip(
          message: task.priority == 3
              ? 'Высокий приоритет'
              : task.priority == 1
                  ? 'Низкий приоритет'
                  : 'Средний приоритет',
          child: Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppColors.priorityDot(task.priority),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.text,
            ),
          ),
        ),
        if (task.cycleDormant)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '(запланирована)',
              style: TextStyle(fontSize: 10, color: AppColors.slate400),
            ),
          ),
        if (task.amount != 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Сумма: ${formatAmount(task.amount)}',
              child: Text(
                '${task.amount > 0 ? '+' : '−'}\$',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Даты: слева начало, справа дедлайн ----------

  Widget _buildDateRow(VaultTask task) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _DateChip(value: task.startDate),
        _DateChip(value: task.deadline),
      ],
    );
  }

  // ---------- Теги + прогресс блокирующих ----------

  Widget _buildTagsAndBlockers(VaultTask task, List<BlockerInfo> blockers) {
    return Row(
      children: [
        if (task.tags.isNotEmpty)
          Flexible(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: task.tags.map((name) {
                final tagData = widget.controller.tags
                    .where((t) => t.name == name)
                    .firstOrNull;
                final color = tagData?.color ?? '#64748b';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hexToColor(color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
        if (blockers.isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(child: _BlockersProgress(blockers: blockers)),
        ],
      ],
    );
  }

  // ---------- Управление циклом ----------

  Widget _buildCycleControls(VaultTask task, String doneListName) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _cycleButton(
          'Выполнено',
          background: AppColors.green,
          title: task.isBlocked
              ? 'Сначала выполните блокирующие задачи'
              : 'Отметить выполненной и создать следующую итерацию',
          enabled: !task.isBlocked,
          onTap: () => _cycleComplete(task, doneListName),
        ),
        _cycleButton(
          'Пропустить',
          foreground: AppColors.green,
          title: 'Сдвинуть срок на следующий цикл без записи в истории',
          onTap: () => widget.controller.skipCycle(task.id!),
        ),
        _cycleButton(
          'Остановить',
          background: AppColors.slate400,
          title: 'Остановить цикл — новые копии создаваться не будут',
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Остановить цикл?'),
                content: Text(
                  'Новые копии задачи «${task.title}» создаваться больше не будут.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Остановить'),
                  ),
                ],
              ),
            );
            if (ok == true) widget.controller.stopCycle(task.id!);
          },
        ),
        _cycleButton(
          'История',
          foreground: AppColors.textMuted,
          title: 'История выполненных итераций',
          onTap: () => _showHistory(task),
        ),
      ],
    );
  }

  Widget _cycleButton(String label,
      {Color? background,
      Color? foreground,
      String? title,
      VoidCallback? onTap,
      bool enabled = true}) {
    final fg = foreground ?? Colors.white;
    return Tooltip(
      message: title ?? '',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: background == null
                ? Border.all(color: AppColors.slate400)
                as Decoration
                : null,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: enabled ? fg : fg.withOpacity(0.4)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cycleComplete(VaultTask task, String doneListName) async {
    final c = widget.controller;
    // Завершаем итерацию: создаётся следующая копия в «Не начато»,
    // текущая удаляется, в историю пишется запись.
    try {
      c.vault.completeCycle(task.id!);
      c.refresh();
    } on TaskError catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _showHistory(VaultTask task) async {
    final history = widget.controller.vault.cycleHistory(task.cycleGroupId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('История: ${task.title}'),
        content: SizedBox(
          width: 420,
          child: history.isEmpty
              ? const Text(
                  'Записей пока нет — история появляется после выполнения '
                  'или остановки цикла.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (ctx, i) {
                    final h = history[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: h.action == 'completed'
                                  ? AppColors.green
                                  : AppColors.slate400,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${h.taskTitle} '
                              '${h.action == 'completed' ? 'выполнена' : 'цикл остановлен'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${h.loggedAt.day.toString().padLeft(2, '0')}.'
                            '${h.loggedAt.month.toString().padLeft(2, '0')}.'
                            '${h.loggedAt.year} '
                            '${h.loggedAt.hour.toString().padLeft(2, '0')}:'
                            '${h.loggedAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  // ---------- Подложка свайпа ----------

  Widget _buildUnderlay(
      VaultList? nextList, VaultList? prevList, bool isFirst, bool isLast) {
    ({Color color, bool del, bool committed}) hint;
    if (_dragX > 0) {
      hint = isLast
          ? (color: AppColors.red, del: true, committed: _dragX > _swipeThreshold)
          : (
              color: nextList != null ? hexToColor(nextList.color) : AppColors.slate400,
              del: false,
              committed: _dragX > _swipeThreshold
            );
    } else {
      hint = isFirst
          ? (color: AppColors.red, del: true, committed: _dragX.abs() > _swipeThreshold)
          : (
              color: prevList != null ? hexToColor(prevList.color) : AppColors.slate400,
              del: false,
              committed: _dragX.abs() > _swipeThreshold
            );
    }

    final left = _dragX > 0;
    return Positioned.fill(
      child: Align(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: _dragX.abs() + 8,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: hint.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Align(
            alignment: left ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(left: left ? 12 : 0, right: left ? 0 : 12),
              child: hint.del
                  ? const Icon(Icons.delete, color: AppColors.red, size: 20)
                  : Text(
                      left ? nextList?.name ?? '' : prevList?.name ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hint.committed
                            ? Colors.white
                            : hint.color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Действия ----------

  Future<void> _moveTo(VaultList target) async {
    if (target.isDone && widget.task.isBlocked) {
      _showError('Сначала выполните блокирующие задачи');
      return;
    }
    try {
      widget.controller.setTaskList(widget.task.id!, target.name);
    } on TaskError catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _confirmDelete() async {
    final task = widget.task;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text(
          task.isCyclic
              ? 'Удалить циклическую задачу «${task.title}» и ВСЮ её историю?'
              : 'Удалить задачу «${task.title}»?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) widget.controller.deleteTask(task.id!);
  }

  void _openEditor() {
    showDialog<void>(
      context: context,
      builder: (ctx) => TaskFormDialog(
        controller: widget.controller,
        task: widget.task,
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class BlockerInfo {
  final int id;
  final String title;
  final bool isDone;
  BlockerInfo({required this.id, required this.title, required this.isDone});
}

/// Прогресс блокирующих задач: полоса + счётчик done/total, тултип со списком.
class _BlockersProgress extends StatelessWidget {
  final List<BlockerInfo> blockers;
  const _BlockersProgress({required this.blockers});

  @override
  Widget build(BuildContext context) {
    final total = blockers.length;
    final done = blockers.where((b) => b.isDone).length;
    final pct = total == 0 ? 0.0 : done / total;

    return Tooltip(
      message: 'Блокирующие задачи: $done из $total\n'
          '${blockers.map((b) => '${b.isDone ? '✓' : '○'} ${b.title}').join('\n')}',
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                        color: AppColors.slate400.withOpacity(0.5)),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$done/$total',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Чип даты: серый (впереди), оранжевый (сегодня), красный (просрочен).
class _DateChip extends StatelessWidget {
  final DateTime? value;
  const _DateChip({this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dateChipColor(value!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        formatShortDate(value),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
