import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitask_local/ui/theme.dart';

void main() {
  test('hexToColor парсит цвета палитры', () {
    expect(hexToColor('#ef4444'), const Color(0xFFEF4444));
    expect(hexToColor('#64748b'), const Color(0xFF64748B));
  });

  test('formatShortDate: без года в текущем году', () {
    final now = DateTime.now();
    final s = formatShortDate(DateTime(now.year, 10, 12));
    expect(s, '12 окт.');
    expect(formatShortDate(DateTime(2027, 1, 5)), '5 янв. 2027');
  });

  test('formatAmount: знак и разделители', () {
    expect(formatAmount(10000), '+10 000');
    expect(formatAmount(-1500), '−1 500');
    expect(formatAmount(0), '+0');
  });
}
