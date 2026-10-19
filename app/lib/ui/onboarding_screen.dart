/// Экран приветствия: выбор папки-хранилища (vault).
///
/// «Философия Obsidian»: пользователь сам указывает папку, файл tasks.db
/// принадлежит ему; синхронизация — внешними инструментами (Syncthing).
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import 'theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(String path) onVaultSelected;
  const OnboardingScreen({super.key, required this.onVaultSelected});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _manualController = TextEditingController();
  bool _busy = false;
  String? _suggested;

  @override
  void initState() {
    super.initState();
    AppConfig.defaultVaultPath().then((p) {
      if (mounted) setState(() => _suggested = p);
    });
  }

  Future<void> _pickDirectory() async {
    setState(() => _busy = true);
    try {
      String? path;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final dir = await getDirectoryPath(
          confirmButtonText: 'Выбрать хранилище',
        );
        path = dir;
      }
      if (path != null) {
        await _use(path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useSuggested() async {
    if (_suggested == null) return;
    await _use(_suggested!);
  }

  Future<void> _useManual() async {
    final p = _manualController.text.trim();
    if (p.isEmpty) {
      _err('Укажите путь к папке');
      return;
    }
    await _use(p);
  }

  Future<void> _use(String path) async {
    setState(() => _busy = true);
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (!await dir.list().isEmpty) {
        // Папка не пуста — это нормально (Syncthing-хранилище), просто
        // предупреждаем, что база будет создана в ней.
      }
      await widget.onVaultSelected(path);
    } catch (e) {
      _err('Не удалось открыть папку: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _err(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'OMNITASK LOCAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Приватный менеджер задач. Данные хранятся локально, '
                  'в выбранной вами папке. Никаких облаков и серверов.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _busy ? null : _pickDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать папку хранилища'),
                ),
                const SizedBox(height: 12),
                if (_suggested != null) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _useSuggested,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text('Использовать «$_suggested»'),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const Text(
                  'Или укажите путь вручную (удобно для Syncthing):',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: r'Например: D:\Tasks',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _busy ? null : _useManual,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local-first: ваши данные — ваши правила',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.header),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• База задач — один файл tasks.db в выбранной папке\n'
                        '• Синхронизируйте папку Syncthing — приложение '
                        'просто читает и пишет файлы\n'
                        '• Резервные копии делайте сами: облачного '
                        'восстановления нет',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
