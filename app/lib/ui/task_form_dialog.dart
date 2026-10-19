/// Редактор задачи — порт TaskForm.jsx из справочного проекта.
///
/// Поля: название, даты, приоритет, статус(список), сумма с валютой,
/// описание с Markdown-предпросмотром, теги, блокирующие задачи,
/// циклические настройки, история изменений.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../vault.dart';
import '../app_controller.dart';
import 'theme.dart';

class TaskFormDialog extends StatefulWidget {
  final AppController controller;
  final VaultTask? task; // null — создание

  const TaskFormDialog({super.key, required this.controller, this.task});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _amountStr;

  DateTime? _startDate;
  DateTime? _deadline;
  int _priority = 1;
  String _listName = '';
  bool _amountIncome = false; // true — доход (+), false — расход (−)
  int? _currencyId;
  bool _descPreview = false;

  final Set<String> _selectedTags = {};
  final Set<int> _selectedBlockers = {};

  bool _isCyclic = false;
  String _cyclePeriod = 'monthly';
  final TextEditingController _cycleIntervalCtrl = TextEditingController();
  final TextEditingController _reminderDaysCtrl = TextEditingController();

  List<ChangeLogEntry> _changes = [];

  AppController get c => widget.controller;
  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _amountStr = TextEditingController(
        text: t != null && t.amount != 0 ? t.amount.abs().toString() : '');
    _amountIncome = t != null && t.amount > 0;
    _startDate = t?.startDate;
    _deadline = t?.deadline;
    _priority = t?.priority ?? 1;
    _currencyId = t?.currencyId ?? c.currencies.firstOrNull?.id;
    _listName = t?.listName ?? c.lists.first.name;
    _descPreview = isEditing && (t?.description.isNotEmpty ?? false);
    _cycleIntervalCtrl.text = '${t?.cycleInterval ?? 1}';
    _reminderDaysCtrl.text = '${t?.reminderDays ?? 0}';
    if (t != null) {
      _selectedTags.addAll(t.tags);
      _selectedBlockers.addAll(t.blockedBy);
      _isCyclic = t.isCyclic;
      _cyclePeriod = t.cyclePeriod;
      _changes = c.vault.changeHistory(t.id!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amountStr.dispose();
    _cycleIntervalCtrl.dispose();
    _reminderDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 680;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      actionsPadding: const EdgeInsets.all(8),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 760 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(color: AppColors.header),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Изменить задачу' : 'Создать задачу',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: buildLeftColumn()),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: buildRightColumn()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buildLeftColumn(),
                          const SizedBox(height: 20),
                          buildRightColumn(),
                        ],
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isEditing)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Удалить'),
                      style:
                          TextButton.styleFrom(foregroundColor: AppColors.red),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green),
                        onPressed: _save,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(isEditing ? 'Сохранить' : 'Создать задачу'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
      );

  // ---------- Левая колонка ----------

  Widget buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Название'),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            hintText: 'Введите название задачи',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _dateField('Дата начала', _startDate,
                    (d) => setState(() => _startDate = d))),
            const SizedBox(width: 12),
            Expanded(
                child: _dateField('Дата завершения', _deadline,
                    (d) => setState(() => _deadline = d))),
          ],
        ),
        const SizedBox(height: 12),
        // Циклическая задача.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _isCyclic = !_isCyclic),
                child: Row(
                  children: [
                    Checkbox(
                        value: _isCyclic,
                        onChanged: (v) =>
                            setState(() => _isCyclic = v ?? false)),
                    const Expanded(
                      child: Text(
                        'Циклическая задача — будет автоматически '
                        'создаваться заново',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCyclic) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isDense: true,
                        value: _cyclePeriod,
                        decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Период',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'daily', child: Text('Ежедневно')),
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Еженедельно')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Ежемесячно')),
                          DropdownMenuItem(
                              value: 'yearly', child: Text('Ежегодно')),
                        ],
                        onChanged: (v) =>
                            setState(() => _cyclePeriod = v ?? 'monthly'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cycleIntervalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Каждые N',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _reminderDaysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Показ. за (дней)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isDense: true,
                isExpanded: true,
                value: _priority,
                decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Приоритет',
                    border: OutlineInputBorder()),
                items: [
                  for (final e in priorityLabels.entries)
                    DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isDense: true,
                isExpanded: true,
                value: _listName,
                decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Статус',
                    border: OutlineInputBorder()),
                items: [
                  for (final l in c.lists)
                    DropdownMenuItem(
                        value: l.name,
                        child: Text(l.name,
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _listName = v ?? _listName),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateField(
      String labelText, DateTime? value, ValueChanged<DateTime?> onChanged) {
    final fmt = value == null
        ? 'Не указана'
        : DateFormat('dd.MM.yyyy HH:mm').format(value);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (time == null) {
          onChanged(DateTime(date.year, date.month, date.day));
          return;
        }
        onChanged(
            DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          labelText: labelText,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(fmt, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // ---------- Правая колонка ----------

  Widget buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Сумма (финансовый вес)'),
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _amountIncome = !_amountIncome),
              borderRadius: BorderRadius.circular(6),
              child: Tooltip(
                message: _amountIncome
                    ? 'Доход (нажмите для расхода)'
                    : 'Расход (нажмите для дохода)',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _amountIncome ? AppColors.accent : AppColors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _amountIncome ? '+' : '−',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _amountStr,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: '0',
                  suffixIcon: _currencySymbol.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(right: 10, top: 14),
                          child: Text(_currencySymbol,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _currencyId,
                hint: const Text('—'),
                items: [
                  for (final cur in c.currencies)
                    DropdownMenuItem(value: cur.id, child: Text(cur.code)),
                ],
                onChanged: (v) => setState(() => _currencyId = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label('Описание'),
            TextButton(
              onPressed: () => setState(() => _descPreview = !_descPreview),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Text(_descPreview ? '✎ Редактировать' : '👁 Предпросмотр',
                  style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
        if (_descPreview && _description.text.trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minHeight: 96),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: MarkdownBody(
              data: _description.text,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(fontSize: 13, height: 1.5),
                listBullet: const TextStyle(fontSize: 13),
              ),
            ),
          )
        else if (_descPreview)
          const Text('Описание пусто',
              style: TextStyle(fontSize: 12, color: AppColors.slate400))
        else
          TextField(
            controller: _description,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText:
                  'Введите описание задачи (поддерживается Markdown: '
                  '**жирный**, *курсив*, списки, [ссылки](url), `код`)',
            ),
          ),
        const SizedBox(height: 16),
        label('Теги'),
        _buildTagPicker(),
        const SizedBox(height: 16),
        label('Блокирующие задачи'),
        _buildBlockersPicker(),
        const SizedBox(height: 4),
        const Text(
          'Эти задачи должны быть выполнены до того, как данную '
          'можно будет отметить «Готово».',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        if (isEditing && _changes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          label('История изменений'),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _changes.length,
              itemBuilder: (ctx, i) {
                final ch = _changes[_changes.length - 1 - i];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(_describeChange(ch),
                              style: const TextStyle(fontSize: 11))),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(ch.changedAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate400),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  String get _currencySymbol {
    for (final cur in c.currencies) {
      if (cur.id == _currencyId) return cur.symbol;
    }
    return '';
  }

  Widget _buildTagPicker() {
    final available = c.tags;
    final unselected =
        available.where((t) => !_selectedTags.contains(t.name)).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final name in _selectedTags)
          _chip(name, hexToColor(_tagColor(name)), onRemove: () {
            setState(() => _selectedTags.remove(name));
          }),
        for (final t in unselected)
          _chip(t.name, hexToColor(t.color), onTap: () {
            setState(() => _selectedTags.add(t.name));
          }),
        ActionChip(
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          label: const Text('+ тег',
              style: TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: AppColors.accent,
          onPressed: _createTag,
        ),
      ],
    );
  }

  String _tagColor(String name) {
    for (final t in c.tags) {
      if (t.name == name) return t.color;
    }
    return '#64748b';
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый тег'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Имя тега'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Создать')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _selectedTags.add(name));
      // Тег создаётся в БД при сохранении задачи (ensureTag).
    }
  }

  Widget _chip(String text, Color color,
      {VoidCallback? onTap, VoidCallback? onRemove}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 10, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockersPicker() {
    final candidates = c.tasks
        .where((t) => t.id != widget.task?.id && !t.isDone)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    if (candidates.isEmpty) {
      return const Text('Нет подходящих задач на доске',
          style: TextStyle(fontSize: 12, color: AppColors.slate400));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final t in candidates)
            InkWell(
              onTap: () => setState(() {
                if (!_selectedBlockers.remove(t.id)) {
                  _selectedBlockers.add(t.id!);
                }
              }),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _selectedBlockers.contains(t.id)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _describeChange(ChangeLogEntry ch) {
    const labels = priorityLabels;
    switch (ch.field) {
      case 'description':
        return 'Описание задания изменено';
      case 'priority':
        return 'Приоритет: «${labels[int.tryParse(ch.oldValue ?? '')] ?? '—'}» '
            '→ «${labels[int.tryParse(ch.newValue ?? '')] ?? '—'}»';
      case 'amount':
        String f(String? v) {
          final n = double.tryParse(v ?? '');
          if (n == null) return '—';
          return formatAmount(n);
        }

        return 'Сумма: «${f(ch.oldValue)}» → «${f(ch.newValue)}»';
      case 'list':
        return 'Статус: «${ch.oldValue ?? '—'}» → «${ch.newValue ?? '—'}»';
      case 'start_date':
        return 'Дата начала: «${_logDate(ch.oldValue)}» → «${_logDate(ch.newValue)}»';
      case 'deadline':
        return 'Дата завершения: «${_logDate(ch.oldValue)}» → «${_logDate(ch.newValue)}»';
      default:
        return ch.field;
    }
  }

  String _logDate(String? ms) {
    final v = ms == null ? null : int.tryParse(ms);
    if (v == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(v);
    const months = [
      'янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.',
      'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ---------- Сохранение ----------

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название задачи обязательно')));
      return;
    }
    final amount = _computeAmount();
    final data = VaultTask(
      boardId: widget.task?.boardId ?? 0,
      title: title,
      description: _description.text,
      startDate: _startDate,
      deadline: _deadline,
      priority: _priority,
      amount: amount,
      currencyId: amount == 0 ? null : _currencyId,
      listName: _listName,
      isCyclic: _isCyclic,
      cyclePeriod: _cyclePeriod,
      cycleInterval: int.tryParse(_cycleIntervalCtrl.text) ?? 1,
      reminderDays: int.tryParse(_reminderDaysCtrl.text) ?? 0,
    );
    try {
      if (isEditing) {
        c.updateTask(widget.task!.id!, data,
            tags: _selectedTags.toList(),
            blockers: _selectedBlockers.toList());
      } else {
        c.createTask(data,
            tags: _selectedTags.toList(),
            blockers: _selectedBlockers.toList());
      }
      Navigator.pop(context);
    } on TaskError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  double _computeAmount() {
    final v = double.tryParse(_amountStr.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return 0;
    return _amountIncome ? v : -v;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text(
            'Вы уверены, что хотите удалить задачу «${widget.task!.title}»?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      c.deleteTask(widget.task!.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}
