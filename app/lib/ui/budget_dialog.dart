/// Бюджет доски — порт BudgetTab справочного проекта.
///
/// Итоги (ПЛАН/ФАКТ/ИТОГО, доход/расход) считаются в валюте расчёта
/// доски; записи показывают эквивалент в валюте расчёта (исходная
/// сумма — при отсутствии курса, с предупреждением).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import '../models.dart';
import '../vault.dart';
import 'theme.dart';

/// «10 000» — без знака, разделители тысяч.
String fmtMoney(num n) {
  final fixed = n.abs().toStringAsFixed(2);
  final cut =
      fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  return cut.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
}

/// «+10 000» / «−10 000».
String signedMoney(num n) => '${n < 0 ? '−' : '+'}${fmtMoney(n)}';

class BudgetDialog extends StatefulWidget {
  const BudgetDialog({super.key});

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    if (c.activeBoardId == null) {
      return const AlertDialog(
          title: Text('Бюджет'), content: Text('Нет досок'));
    }

    final BudgetReport b;
    try {
      b = c.budget;
    } on TaskError catch (e) {
      return AlertDialog(
        title: const Text('Бюджет'),
        content: Text(e.message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть')),
        ],
      );
    }

    final currencies = c.currencies;
    final doneNames =
        c.lists.where((l) => l.kind == 'done').map((l) => l.name).toSet();

    final incomeAbs = b.income.abs();
    final expenseAbs = b.expense.abs();
    final sum = incomeAbs + expenseAbs;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              size: 20, color: AppColors.header),
          const SizedBox(width: 8),
          const Text('Бюджет'),
          const Spacer(),
          // Валюта расчёта.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Валюта:',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: b.reportCurrencyId,
                    isDense: true,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          currencies.isEmpty
                              ? '—'
                              : '${currencies.first.code} ★',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted),
                        ),
                      ),
                      for (final cur in currencies.where(
                          (x) => x.id != b.reportCurrencyId))
                        DropdownMenuItem<int?>(
                          value: cur.id,
                          child: Text(cur.code,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                    onChanged: (v) => c.setReportCurrency(v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (b.missingRate)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠ У одной или нескольких валют не указан курс — '
                  'обновите «Валюты», иначе итоги будут неполными.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ),
            // План / Баланс / Факт.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _TotalsCell(
                          label: 'ПЛАН', value: signedMoney(b.plan))),
                  Container(
                      width: 1, height: 34, color: const Color(0xFFE2E8F0)),
                  Expanded(
                      child: _TotalsCell(
                    label: 'БАЛАНС',
                    value: signedMoney(b.total),
                    big: true,
                    color: b.total > 0
                        ? AppColors.green
                        : b.total < 0
                            ? AppColors.red
                            : AppColors.text,
                  )),
                  Container(
                      width: 1, height: 34, color: const Color(0xFFE2E8F0)),
                  Expanded(
                      child: _TotalsCell(
                          label: 'ФАКТ', value: signedMoney(b.fact))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Полоса доход/расход.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (incomeAbs > 0 && sum > 0)
                      Expanded(
                        flex: (incomeAbs / sum * 100).round().clamp(1, 100),
                        child: Container(color: AppColors.green),
                      ),
                    if (expenseAbs > 0 && sum > 0)
                      Expanded(
                        flex: (expenseAbs / sum * 100).round().clamp(1, 100),
                        child: Container(color: AppColors.red),
                      ),
                    if (sum == 0)
                      Expanded(
                          child:
                              Container(color: const Color(0xFFE2E8F0))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendDot(
                    color: AppColors.green,
                    label: 'Доходы',
                    value: signedMoney(b.income)),
                _LegendDot(
                    color: AppColors.red,
                    label: 'Расходы',
                    value: signedMoney(b.expense)),
              ],
            ),
            const SizedBox(height: 10),
            // Записи.
            if (b.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Задач с суммой пока нет — укажите сумму в форме задачи '
                  '(доход или расход).',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: b.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = b.entries[i];
                    final done = doneNames.contains(e.list);
                    final value = e.converted != null
                        ? signedMoney(e.converted!)
                        : '${signedMoney(e.amount)}'
                            '${e.currencyCode != null ? ' ${e.currencyCode}' : ''}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: done
                                    ? AppColors.slate400
                                    : AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.converted != null ? value : '$value ⚠',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: done
                                  ? AppColors.slate400
                                  : e.converted != null
                                      ? AppColors.text
                                      : AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: b.entries.isEmpty
              ? null
              : () async {
                  await _copyReport(c, b, doneNames);
                  if (!mounted) return;
                  setState(() => _copied = true);
                  await Future<void>.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _copied = false);
                },
          icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
          label: Text(_copied ? 'Скопировано ✓' : 'Копировать'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.header),
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  /// Текстовый отчёт — как buildReport в справочном проекте.
  Future<void> _copyReport(
      AppController c, BudgetReport b, Set<String> doneNames) async {
    const line = '--------------------------------';
    String entryLine(BudgetEntry e) {
      final value = e.converted != null
          ? signedMoney(e.converted!)
          : '${signedMoney(e.amount)}'
              '${e.currencyCode != null ? ' ${e.currencyCode}' : ''}';
      return '${e.title}: $value';
    }

    final sorted = [...b.entries]
      ..sort((a, z) {
        final ta = c.tasks.where((t) => t.id == a.taskId).firstOrNull;
        final tz = c.tasks.where((t) => t.id == z.taskId).firstOrNull;
        final da = ta?.deadline?.millisecondsSinceEpoch ?? 1 << 62;
        final dz = tz?.deadline?.millisecondsSinceEpoch ?? 1 << 62;
        if (da != dz) return da.compareTo(dz);
        return a.title.compareTo(z.title);
      });
    final fact = sorted.where((e) => doneNames.contains(e.list)).toList();
    final plan = sorted.where((e) => !doneNames.contains(e.list)).toList();
    final code = b.reportCurrencyCode ?? '';
    final report = [
      '${c.activeBoard?.name ?? ''} — Бюджет${code.isEmpty ? '' : ' ($code)'}',
      line,
      fact.map(entryLine).join('\n'),
      plan.map(entryLine).join('\n'),
      line,
      'ПЛАН: ${signedMoney(b.plan)} $code',
      'ФАКТ: ${signedMoney(b.fact)} $code',
      line,
      'ВСЕГО ДОХОД: ${signedMoney(b.income)} $code',
      'ВСЕГО РАСХОД: ${signedMoney(b.expense)} $code',
      'ИТОГО: ${signedMoney(b.total)} $code',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: report));
  }
}

class _TotalsCell extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? color;

  const _TotalsCell(
      {required this.label,
      required this.value,
      this.big = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final v = color ??
        (value.startsWith('−') ? AppColors.red : AppColors.text);
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 17 : 13,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: v,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendDot(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}
