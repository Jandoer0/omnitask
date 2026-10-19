/// Диалоги: переключатель досок, менеджер списков, валют, настройки,
/// выбор папки хранилища, «О программе».
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import '../models.dart';
import '../vault.dart';
import 'theme.dart';

/// Диалог досок: список, переключение, создание/редактирование/удаление.
class BoardSwitcherDialog extends StatelessWidget {
  const BoardSwitcherDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return SimpleDialog(
      title: const Text('Доски'),
      contentPadding: const EdgeInsets.only(top: 8),
      children: [
        for (final b in c.boards)
          ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: hexToColor(b.color),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(b.name,
                style: TextStyle(
                    fontWeight: b.id == c.activeBoardId
                        ? FontWeight.w700
                        : FontWeight.w400)),
            subtitle: b.description.isEmpty ? null : Text(b.description),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => _BoardFormDialog(board: b),
                  );
                } else if (v == 'delete') {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => _BoardFormDialog(board: b, deleting: true),
                  );
                } else if (v == 'switch') {
                  c.switchBoard(b.id!);
                  Navigator.pop(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'switch',
                    child: Row(children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Перейти'),
                    ])),
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Изменить'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete),
                      SizedBox(width: 8),
                      Text('Удалить'),
                    ])),
              ],
            ),
            onTap: () {
              c.switchBoard(b.id!);
              Navigator.pop(context);
            },
          ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.accent),
          title: const Text('Новая доска'),
          onTap: () {
            Navigator.pop(context);
            showDialog<void>(
              context: context,
              builder: (ctx) => const _BoardFormDialog(),
            );
          },
        ),
      ],
    );
  }
}

/// Создание/редактирование/удаление доски.
class _BoardFormDialog extends StatefulWidget {
  final VaultBoard? board;
  final bool deleting;
  const _BoardFormDialog({this.board, this.deleting = false});

  @override
  State<_BoardFormDialog> createState() => _BoardFormDialogState();
}

class _BoardFormDialogState extends State<_BoardFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.board?.name ?? '');
    _description =
        TextEditingController(text: widget.board?.description ?? '');
    _color = widget.board?.color ?? kBoardPalette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    if (widget.deleting) {
      return AlertDialog(
        title: const Text('Удалить доску?'),
        content: Text(
            'Доска «${widget.board!.name}» и все её задачи будут удалены. '
            'Последнюю доску удалить нельзя.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () {
                try {
                  c.deleteBoard(widget.board!.id!);
                } on TaskError catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Удалить')),
        ],
      );
    }

    return AlertDialog(
      title:
          Text(widget.board == null ? 'Новая доска' : 'Изменить доску'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ЦВЕТ',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in kBoardPalette)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: hexToColor(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _save,
            child: Text(widget.board == null ? 'Создать' : 'Сохранить')),
      ],
    );
  }

  void _save() {
    final c = context.read<AppController>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название доски обязательно')));
      return;
    }
    if (widget.board == null) {
      c.createBoard(name, _description.text, _color);
    } else {
      c.updateBoard(widget.board!.id!,
          name: name, description: _description.text, color: _color);
    }
    Navigator.pop(context);
  }
}

/// Менеджер списков доски: добавить/переименовать/цвет/kind/удалить.
class ListsManagerDialog extends StatelessWidget {
  const ListsManagerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final lists = [...c.lists]..sort((a, b) => a.position.compareTo(b.position));

    return SimpleDialog(
      title: const Text('Списки'),
      contentPadding: const EdgeInsets.only(top: 8),
      children: [
        for (final l in lists)
          ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: hexToColor(l.color),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(l.name),
            subtitle: Text(
              switch (l.kind) {
                'done' => 'завершённые',
                'progress' => 'в работе',
                _ => 'к выполнению',
              },
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => _ListFormDialog(list: l),
                    );
                    break;
                  case 'delete':
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => _ListFormDialog(list: l, deleting: true),
                    );
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Изменить'),
                    ])),
                PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete),
                      SizedBox(width: 8),
                      Text('Удалить'),
                    ])),
              ],
            ),
          ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.accent),
          title: const Text('Новый список'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => const _ListFormDialog(),
          ),
        ),
      ],
    );
  }
}

class _ListFormDialog extends StatefulWidget {
  final VaultList? list;
  final bool deleting;
  const _ListFormDialog({this.list, this.deleting = false});

  @override
  State<_ListFormDialog> createState() => _ListFormDialogState();
}

class _ListFormDialogState extends State<_ListFormDialog> {
  late final TextEditingController _name;
  late String _color;
  late String _kind;

  static const _kinds = {
    'todo': 'К выполнению',
    'progress': 'В работе',
    'done': 'Завершённые',
  };

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.list?.name ?? '');
    _color = widget.list?.color ?? kPalette.first;
    _kind = widget.list?.kind ?? 'todo';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    if (widget.deleting) {
      return AlertDialog(
        title: const Text('Удалить список?'),
        content: Text(
            'Задачи списка «${widget.list!.name}» будут перенесены '
            'в первый оставшийся список.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () {
                try {
                  c.deleteList(widget.list!.id!);
                } on TaskError catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Удалить')),
        ],
      );
    }

    return AlertDialog(
      title:
          Text(widget.list == null ? 'Новый список' : 'Изменить список'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _kind,
              isDense: true,
              decoration: const InputDecoration(
                  labelText: 'Свойство', border: OutlineInputBorder()),
              items: [
                for (final e in _kinds.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'todo'),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ЦВЕТ',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in kPalette)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: hexToColor(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _save,
            child: Text(widget.list == null ? 'Создать' : 'Сохранить')),
      ],
    );
  }

  void _save() {
    final c = context.read<AppController>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название списка обязательно')));
      return;
    }
    try {
      if (widget.list == null) {
        c.addList(name, color: _color, kind: _kind);
      } else {
        c.updateList(widget.list!.id!,
            name: name, color: _color, kind: _kind);
      }
    } on TaskError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    Navigator.pop(context);
  }
}

/// Менеджер валют: код, название, символ, курс к USD.
class CurrencyManagerDialog extends StatefulWidget {
  const CurrencyManagerDialog({super.key});

  @override
  State<CurrencyManagerDialog> createState() => _CurrencyManagerDialogState();
}

class _CurrencyManagerDialogState extends State<CurrencyManagerDialog> {
  void _reload() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    final currencies = c.currencies;

    void move(int from, int to) {
      if (to < 0 || to >= currencies.length) return;
      final ids = [for (final x in currencies) x.id!];
      final t = ids.removeAt(from);
      ids.insert(to, t);
      c.reorderCurrencies(ids);
      _reload();
    }

    return SimpleDialog(
      title: const Text('Валюты'),
      contentPadding: const EdgeInsets.only(top: 8),
      children: [
        if (currencies.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Первая валюта в списке — валюта по умолчанию '
              '(и базовая для бюджета).',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        for (final cur in currencies)
          ListTile(
            leading: SizedBox(
              width: 44,
              child: Text(cur.code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.header)),
            ),
            title: Text(cur.name),
            subtitle: Text(
              '${cur.symbol} • курс: '
              '${cur.rate == null ? 'не указан' : cur.rate!.toStringAsFixed(4)} к USD',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => move(currencies.indexOf(cur),
                          currencies.indexOf(cur) - 1),
                      child: const Icon(Icons.arrow_upward, size: 14),
                    ),
                    InkWell(
                      onTap: () => move(currencies.indexOf(cur),
                          currencies.indexOf(cur) + 1),
                      child: const Icon(Icons.arrow_downward, size: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) =>
                        _CurrencyFormDialog(currency: cur, onSaved: _reload),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () {
                    c.vault.deleteCurrency(cur.id!);
                    _reload();
                  },
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.accent),
          title: const Text('Новая валюта'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) =>
                _CurrencyFormDialog(onSaved: _reload),
          ),
        ),
      ],
    );
  }
}

class _CurrencyFormDialog extends StatefulWidget {
  final VaultCurrency? currency;
  final VoidCallback onSaved;
  const _CurrencyFormDialog({this.currency, required this.onSaved});

  @override
  State<_CurrencyFormDialog> createState() => _CurrencyFormDialogState();
}

class _CurrencyFormDialogState extends State<_CurrencyFormDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _symbol;
  late final TextEditingController _rate;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.currency?.code ?? '');
    _name = TextEditingController(text: widget.currency?.name ?? '');
    _symbol = TextEditingController(text: widget.currency?.symbol ?? '');
    _rate = TextEditingController(
        text: widget.currency?.rate?.toString() ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _symbol.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.currency == null ? 'Новая валюта' : 'Изменить валюту'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Код',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Название',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _symbol,
                    decoration: const InputDecoration(
                        labelText: 'Символ',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Курс к USD (1 ед. = ? USD)',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Курс — стоимость 1 единицы валюты в USD. '
              'Например, 0.011 для RUB: 10 000 ₽ ≈ 110 \$.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _save,
            child: const Text('Сохранить')),
      ],
    );
  }

  void _save() {
    final c = context.read<AppController>();
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    try {
      if (widget.currency == null) {
        c.vault.createCurrency(
            _code.text, _name.text, _symbol.text, rate);
      } else {
        c.vault.updateCurrency(widget.currency!.id!,
            name: _name.text, symbol: _symbol.text, rate: rate);
      }
      widget.onSaved();
      Navigator.pop(context);
    } on TaskError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Настройки: путь к хранилищу, уведомления, предупреждение о backup.
class SettingsDialog extends StatelessWidget {
  final Future<void> Function(String path)? onChangeVault;
  const SettingsDialog({super.key, this.onChangeVault});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return AlertDialog(
      title: const Text('Настройки'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ХРАНИЛИЩЕ',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 18, color: AppColors.header),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.vault.vaultPath,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (onChangeVault != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      tooltip: 'Сменить папку хранилища',
                      onPressed: () async {
                        final path = await _pickVault(context);
                        if (path != null) {
                          await onChangeVault!(path);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Уведомления о дедлайнах'),
              subtitle: const Text(
                'Напоминать о задачах с дедлайном в течение 24 часов '
                'и о просроченных',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              value: c.notificationsEnabled,
              onChanged: (v) => c.setNotificationsEnabled(v),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ Нет облачного восстановления',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color(0xFF92400E))),
                  SizedBox(height: 4),
                  Text(
                    'Omnitask Local — local-first приложение. Все данные '
                    'лежат в файле tasks.db в выбранной папке. Делайте '
                    'резервные копии и/или синхронизируйте папку через '
                    'Syncthing. Потерянные данные восстановить негде.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть')),
      ],
    );
  }

  Future<String?> _pickVault(BuildContext context) async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return await getDirectoryPath(confirmButtonText: 'Выбрать хранилище');
    }
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => const AlertDialog(
          title: Text('Смена хранилища на Android'),
          content: Text(
              'На Android используйте экран приветствия при следующем '
              'запуске приложения или подключите устройство к ПК, чтобы '
              'переместить папку хранилища.',
          ),
        ),
      );
    }
    return null;
  }
}

/// Выбор новой папки хранилища (полноэкранный сценарий).
class VaultPathSelectorDialog extends StatelessWidget {
  final String current;
  final void Function(String path) onSave;
  const VaultPathSelectorDialog(
      {super.key, required this.current, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Изменить хранилище'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Текущее: $current'),
          const SizedBox(height: 8),
          const Text(
            'Выберите новую папку. База tasks.db будет создана в ней; '
            'старая папка останется нетронутой.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () async {
            if (!kIsWeb &&
                (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS)) {
              final path = await getDirectoryPath(
                  confirmButtonText: 'Выбрать хранилище');
              if (path != null) {
                onSave(path);
                if (context.mounted) Navigator.pop(context);
              }
            } else {
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Выбрать папку'),
        ),
      ],
    );
  }
}

/// «О программе».
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Omnitask Local'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Версия 0.1.0 (MVP)'),
          SizedBox(height: 8),
          Text(
            'Приватный local-first менеджер задач для Windows и Android. '
            'Основан на функционале и оформлении справочного проекта '
            'OmniTask (mcp-todo), без облака, пользователей и MCP.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          SizedBox(height: 8),
          Text(
            '• Данные: SQLite (tasks.db) в вашей папке\n'
            '• Синхронизация: Syncthing (внешняя)\n'
            '• Уведомления: локальные, без сети',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть')),
      ],
    );
  }
}
