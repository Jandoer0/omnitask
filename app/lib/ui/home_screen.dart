/// Главный экран — порт Dashboard + Board.jsx из справочного проекта.
///
/// Шапка с переключателем досок, строка фильтров-сводки, облако тегов,
/// кнопка «+ Новая задача», сворачиваемые группы списков с карточками.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import '../models.dart';
import 'budget_dialog.dart';
import 'dialogs.dart';
import 'task_card.dart';
import 'task_form_dialog.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  final Future<void> Function(String path) onChangeVault;
  const HomeScreen({super.key, required this.onChangeVault});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: Colors.white,
        title: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => const BoardSwitcherDialog(),
          ),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.activeBoard == null
                        ? Colors.white
                        : hexToColor(c.activeBoard!.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    c.activeBoard?.name ?? 'Omnitask',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 18, color: Colors.white70),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Списки',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => const ListsManagerDialog(),
            ),
            icon: const Icon(Icons.view_column),
          ),
          PopupMenuButton<String>(
            tooltip: 'Меню',
            icon: const Icon(Icons.menu),
            onSelected: (v) {
              switch (v) {
                case 'budget':
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const BudgetDialog(),
                  );
                  break;
                case 'currencies':
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const CurrencyManagerDialog(),
                  );
                  break;
                case 'settings':
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => SettingsDialog(onChangeVault: onChangeVault),
                  );
                  break;
                case 'about':
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const AboutAppDialog(),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'budget',
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet),
                    SizedBox(width: 8),
                    Text('Бюджет'),
                  ])),
              const PopupMenuItem(
                  value: 'currencies',
                  child: Row(children: [
                    Icon(Icons.attach_money),
                    SizedBox(width: 8),
                    Text('Валюты'),
                  ])),
              const PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.tune),
                    SizedBox(width: 8),
                    Text('Настройки'),
                  ])),
              const PopupMenuItem(
                  value: 'about',
                  child: Row(children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('О программе'),
                  ])),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'omnitask-new-task',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) =>
              TaskFormDialog(controller: context.read<AppController>()),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Новая задача'),
      ),
      body: c.activeBoard == null
          ? const Center(
              child: Text('Нет досок',
                  style: TextStyle(color: Colors.white54)),
            )
          : _BoardBody(controller: c),
    );
  }
}

/// Строка фильтров + облако тегов + группы списков.
class _BoardBody extends StatelessWidget {
  final AppController controller;
  const _BoardBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.summary;
    return Column(
      children: [
        // Сводка-фильтры.
        if (s != null)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _FilterChip('Всего', s.total, AppColors.accent,
                    c.activeFilter == TaskFilter.all, () {
                  c.setFilter(TaskFilter.all);
                }),
                _FilterChip('К выполнению', s.todo, AppColors.orange,
                    c.activeFilter == TaskFilter.todo, () {
                  c.setFilter(TaskFilter.todo);
                }),
                _FilterChip('В работе', s.inProgress,
                    const Color(0xFF8B5CF6),
                    c.activeFilter == TaskFilter.inProgress, () {
                  c.setFilter(TaskFilter.inProgress);
                }),
                _FilterChip('Готово', s.done, AppColors.green,
                    c.activeFilter == TaskFilter.done, () {
                  c.setFilter(TaskFilter.done);
                }),
                _FilterChip('Просрочено', s.overdue, AppColors.red,
                    c.activeFilter == TaskFilter.overdue, () {
                  c.setFilter(TaskFilter.overdue);
                }),
                _FilterChip('Запланировано', s.planned, AppColors.slate400,
                    c.activeFilter == TaskFilter.planned, () {
                  c.setFilter(TaskFilter.planned);
                }),
              ],
            ),
          ),
        // Облако тегов.
        if (c.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in c.tags)
                  InkWell(
                    onTap: () => c.toggleTag(tag.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hexToColor(tag.color),
                        borderRadius: BorderRadius.circular(4),
                        border: c.activeTagId == tag.id
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Text(
                        tag.name,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                if (c.activeTagId != null)
                  TextButton(
                    onPressed: () => c.toggleTag(c.activeTagId),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('✕ Очистить',
                        style: TextStyle(
                            fontSize: 11, color: Colors.white54)),
                  ),
              ],
            ),
          ),
        // Группы.
        Expanded(
          child: _GroupsView(controller: c),
        ),
      ],
    );
  }
}

/// Список групп (по одному на список доски) со сворачиванием.
/// «Архив» свёрнут по умолчанию (как в справочном проекте).
class _GroupsView extends StatefulWidget {
  final AppController controller;
  const _GroupsView({required this.controller});

  @override
  State<_GroupsView> createState() => _GroupsViewState();
}

class _GroupsViewState extends State<_GroupsView> {
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final lists = [...c.lists]..sort((a, b) => a.position.compareTo(b.position));
    final visible = c.visibleTasks;

    final groups = <(VaultList, List<VaultTask>)>[
      for (final l in lists)
        (
          l,
          visible.where((t) => t.listName == l.name).toList(),
        ),
    ];
    // Задачи вне известных списков — «Прочее».
    final orphan =
        visible.where((t) => !lists.any((l) => l.name == t.listName)).toList();
    if (orphan.isNotEmpty) {
      groups.add((
        VaultList(name: 'Прочее', color: '#64748b', kind: 'todo'),
        orphan,
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final (list, items) = groups[i];
        final collapsed =
            _collapsed[list.name] ?? list.name == 'Архив';
        return Column(
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _collapsed[list.name] = !collapsed),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      collapsed
                          ? Icons.play_arrow
                          : Icons.expand_more,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: hexToColor(list.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                    Text(
                      '(${items.length})',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (!collapsed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: items.isEmpty
                    ? const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Нет задач',
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.white38),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final t in items)
                            TaskCard(task: t, controller: c),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(this.label, this.count, this.color, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active
              ? Border.all(color: color, width: 1.4)
              : Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? color : color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
