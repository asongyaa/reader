import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class _ScannedFile {
  final File file;
  final String name;
  final String ext;
  final int size;
  final DateTime modified;
  bool selected;

  _ScannedFile({
    required this.file,
    required this.name,
    required this.ext,
    required this.size,
    required this.modified,
    this.selected = false,
  });

  String get sizeLabel {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}

class ScanBooksPage extends ConsumerStatefulWidget {
  const ScanBooksPage({super.key});

  @override
  ConsumerState<ScanBooksPage> createState() => _ScanBooksPageState();
}

class _ScanBooksPageState extends ConsumerState<ScanBooksPage>
    with SingleTickerProviderStateMixin {
  final _tabs = ['ALL', 'EPUB', 'PDF', 'TXT', 'MOBI', 'AZW3'];
  late TabController _tabController;
  List<_ScannedFile> _allFiles = [];
  bool _isScanning = false;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _startScan();
  }

  IconData _fileIcon(String ext) {
    return switch (ext) {
      'EPUB' => Icons.menu_book_rounded,
      'PDF' => Icons.picture_as_pdf_rounded,
      'TXT' => Icons.description_rounded,
      'MOBI' => Icons.book_rounded,
      'AZW3' => Icons.book_rounded,
      'FB2' => Icons.auto_stories_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  Color _fileColor(String ext, ColorScheme cs) {
    return switch (ext) {
      'EPUB' => Colors.teal,
      'PDF' => Colors.red.shade700,
      'TXT' => Colors.blueGrey,
      'MOBI' => Colors.orange.shade700,
      'AZW3' => Colors.deepOrange,
      'FB2' => Colors.indigo,
      _ => cs.onSurfaceVariant,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _allFiles.clear();
    });

    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          if (mounted) {
            setState(() => _isScanning = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要文件访问权限才能扫描')),
            );
          }
          return;
        }
      }
    }

    final dirs = Prefs().scanDirectories;
    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (allowBookExtensions.contains(ext)) {
              final stat = await entity.stat();
              final name = entity.path.split('/').last;
              setState(() {
                _allFiles.add(_ScannedFile(
                  file: entity,
                  name: name.substring(0, name.lastIndexOf('.')),
                  ext: ext.toUpperCase(),
                  size: stat.size,
                  modified: stat.modified,
                ));
              });
            }
          }
        }
      } catch (_) {}
    }

    setState(() => _isScanning = false);
  }

  List<_ScannedFile> get _filteredFiles {
    var files = _allFiles;
    final tab = _tabs[_tabController.index];
    if (tab != 'ALL') {
      files = files.where((f) => f.ext == tab).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      files = files.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    return files;
  }

  void _toggleSelectAll() {
    final filtered = _filteredFiles;
    final allSelected = filtered.every((f) => f.selected);
    setState(() {
      for (final f in filtered) {
        f.selected = !allSelected;
      }
    });
  }

  void _importSelected() async {
    final selected = _allFiles.where((f) => f.selected).toList();
    if (selected.isEmpty) return;

    final tmp = await getAnxTempDir();
    final copiedFiles = <File>[];
    for (final f in selected) {
      final target = File(p.join(tmp.path, p.basename(f.file.path)));
      copiedFiles.add(await f.file.copy(target.path));
    }
    if (!mounted) return;
    importBookList(copiedFiles, context, ref);
  }

  String get _scanRangeLabel {
    final dirs = Prefs().scanDirectories;
    return dirs.map((d) => d.split('/').last).join(', ');
  }

  void _showDirectoryPicker() {
    final dirs = List<String>.from(Prefs().scanDirectories);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择要扫描的文件夹',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text('/storage/emulated/0',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ...dirs.map((dir) => ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(dir.split('/').last),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () {
                                setSheetState(() => dirs.remove(dir));
                              },
                            ),
                          )),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('添加文件夹'),
                        onTap: () async {
                          final path =
                              await FilePicker.platform.getDirectoryPath();
                          if (path != null && !dirs.contains(path)) {
                            setSheetState(() => dirs.add(path));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Prefs().scanDirectories = dirs;
                      Navigator.pop(ctx);
                      _startScan();
                    },
                    child: const Text('确认并重新扫描'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredFiles;
    final selectedCount = _allFiles.where((f) => f.selected).length;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文件名',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('自动扫描'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dirs') _showDirectoryPicker();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'dirs', child: Text('选择扫描目录')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '扫描范围：$_scanRangeLabel',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          Expanded(
            child: filtered.isEmpty && !_isScanning
                ? Center(
                    child: Text('未找到电子书文件',
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final f = filtered[i];
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: f.selected,
                              onChanged: (v) =>
                                  setState(() => f.selected = v ?? false),
                            ),
                            Icon(
                              _fileIcon(f.ext),
                              size: 32,
                              color: _fileColor(f.ext, cs),
                            ),
                          ],
                        ),
                        title: Text(f.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${f.ext}   ${dateFormat.format(f.modified)}   ${f.sizeLabel}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        onTap: () =>
                            setState(() => f.selected = !f.selected),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TextButton(
                onPressed: _toggleSelectAll,
                child: const Text('全选'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: selectedCount > 0 ? _importSelected : null,
                child: Text('导入${selectedCount > 0 ? ' ($selectedCount)' : ''}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
