import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getWorkFolder(
    BuildContext context, SharedPreferences? prefsInstance) async {
  String? folder = prefsInstance?.getString("workFolder");
  if (folder != null && folder.isNotEmpty) return folder;
  final path = await FilePicker.platform.getDirectoryPath(
    dialogTitle:
        AppLocalizations.of(context)!.settingsSetWorkFolder,
  );
  if (path != null) {
    prefsInstance?.setString("workFolder", path);
    return path;
  }
  return null;
}

bool isValidPath(String workFolder, String relativePath) {
  if (relativePath.contains('..')) return false;
  if (relativePath.startsWith('/') || relativePath.startsWith('\\')) {
    return false;
  }
  return true;
}

Future<void> executeFileOperations(
  List<Map<String, dynamic>> operations,
  String workFolder,
  BuildContext context,
) async {
  for (final op in operations) {
    final action = op["action"]?.toString().toLowerCase();
    final file = op["file"]?.toString();
    if (file == null || file.isEmpty) continue;
    if (!isValidPath(workFolder, file)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppLocalizations.of(context)!.fileOperationPathTraversal),
          showCloseIcon: true,
        ));
      }
      continue;
    }
    final fullPath = Platform.pathSeparator == '\\'
        ? '$workFolder\\$file'
        : '$workFolder/$file';
    final dir = Directory(fullPath).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      switch (action) {
        case 'create':
          final content1 = op["content"]?.toString() ?? '';
          await File(fullPath).writeAsString(content1);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.fileOperationCreate}: $file'),
              showCloseIcon: true,
            ));
          }
          break;
        case 'edit':
          final content2 = op["content"]?.toString() ?? '';
          await File(fullPath).writeAsString(content2);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.fileOperationEdit}: $file'),
              showCloseIcon: true,
            ));
          }
          break;
        case 'remove':
          await File(fullPath).delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.fileOperationRemove}: $file'),
              showCloseIcon: true,
            ));
          }
          break;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.fileOperationFailed),
          showCloseIcon: true,
        ));
      }
    }
  }
}

Future<List<Map<String, dynamic>>>? parseFileOperations(String text) {
  final jsonMatches = RegExp(r'```(?:json)?\s*\n?(\[.*?\])\s*\n?```',
      dotMultiline: true).allMatches(text);
  final results = <Map<String, dynamic>>[];
  for (final match in jsonMatches) {
    try {
      final parsed = jsonDecode(match.group(1)!) as List;
      for (final item in parsed) {
        if (item is Map<String, dynamic> &&
            ['create', 'edit', 'remove']
                .contains(item['action']?.toString().toLowerCase()) &&
            item['file'] != null) {
          results.add(item);
        }
      }
    } catch (_) {}
  }
  return results.isEmpty ? null : results;
}
