import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scriptsKey = 'browser_user_scripts';

class UserScript {
  final String name;
  final String code;
  final List<String> matches;

  UserScript({required this.name, required this.code, required this.matches});

  Map<String, dynamic> toMap() => {
    'name': name,
    'code': code,
    'matches': matches,
  };

  factory UserScript.fromMap(Map<String, dynamic> map) => UserScript(
    name: map['name'] as String? ?? '',
    code: map['code'] as String? ?? '',
    matches: (map['matches'] as List?)?.cast<String>() ?? [],
  );
}

class BrowserPage extends StatefulWidget {
  final String initialUrl;
  const BrowserPage({super.key, this.initialUrl = 'https://www.google.com'});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _webViewController;
  final _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0;
  List<UserScript> _scripts = [];

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    _loadScripts();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scriptsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _scripts = list
          .map((e) => UserScript.fromMap(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveScripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _scriptsKey,
        jsonEncode(_scripts.map((s) => s.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('_saveScripts failed: $e');
    }
  }

  void _injectScripts() {
    if (_webViewController == null) return;
    for (final script in _scripts) {
      if (script.code.isEmpty) continue;
      _webViewController!.evaluateJavascript(source: script.code);
    }
  }

  void _goToUrl(String url) {
    var uri = url.trim();
    if (uri.isEmpty) return;
    if (!uri.startsWith('http://') && !uri.startsWith('https://')) {
      uri = 'https://$uri';
    }
    _urlController.text = uri;
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: TextField(
          controller: _urlController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: '输入网址',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              onPressed: () => _goToUrl(_urlController.text),
            ),
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: _goToUrl,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension, size: 20),
            tooltip: '用户脚本',
            onPressed: _showScriptManager,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading && _progress < 1.0)
            LinearProgressIndicator(value: _progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                mixedContentMode:
                    MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                useWideViewPort: true,
                supportZoom: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
                _urlController.text = url.toString();
              },
              onLoadStop: (controller, url) {
                setState(() => _isLoading = false);
                _injectScripts();
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100.0);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _webViewController?.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _webViewController?.reload(),
            ),
          ],
        ),
      ),
    );
  }

  void _showScriptManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ScriptManagerSheet(
        scripts: _scripts,
        onScriptsChanged: (scripts) {
          setState(() => _scripts = scripts);
          _saveScripts();
          _injectScripts();
        },
      ),
    );
  }
}

class _ScriptManagerSheet extends StatefulWidget {
  final List<UserScript> scripts;
  final void Function(List<UserScript>) onScriptsChanged;

  const _ScriptManagerSheet({
    required this.scripts,
    required this.onScriptsChanged,
  });

  @override
  State<_ScriptManagerSheet> createState() => _ScriptManagerSheetState();
}

class _ScriptManagerSheetState extends State<_ScriptManagerSheet> {
  late List<UserScript> _scripts;

  @override
  void initState() {
    super.initState();
    _scripts = List.from(widget.scripts);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            AppBar(
              title: const Text('用户脚本'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  onPressed: _addScript,
                ),
              ],
            ),
            Expanded(
              child: _scripts.isEmpty
                  ? const Center(child: Text('暂无脚本，点击"添加"创建'))
                  : ListView.builder(
                      itemCount: _scripts.length,
                      itemBuilder: (ctx, i) {
                        final s = _scripts[i];
                        return ListTile(
                          title: Text(s.name.isNotEmpty ? s.name : '未命名脚本'),
                          subtitle: Text('${s.matches.length} 个匹配规则'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() => _scripts.removeAt(i));
                              _notifyChanged();
                            },
                          ),
                          onTap: () => _editScript(i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addScript() {
    _scripts.add(UserScript(name: '', code: '', matches: []));
    _editScript(_scripts.length - 1);
  }

  void _editScript(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _ScriptEditDialog(
        script: _scripts[index],
        onSaved: (updated) {
          setState(() => _scripts[index] = updated);
          _notifyChanged();
        },
      ),
    );
  }

  void _notifyChanged() {
    widget.onScriptsChanged(List.from(_scripts));
  }
}

class _ScriptEditDialog extends StatefulWidget {
  final UserScript script;
  final void Function(UserScript) onSaved;

  const _ScriptEditDialog({required this.script, required this.onSaved});

  @override
  State<_ScriptEditDialog> createState() => _ScriptEditDialogState();
}

class _ScriptEditDialogState extends State<_ScriptEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _matchesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.script.name);
    _codeCtrl = TextEditingController(text: widget.script.code);
    _matchesCtrl = TextEditingController(
      text: widget.script.matches.join('\n'),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _matchesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑脚本'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '脚本名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '脚本代码 (JavaScript)',
                  border: OutlineInputBorder(),
                  hintText:
                      '// ==UserScript==\n// @name\n// @match *://*/*\n// ==/UserScript==\n\nconsole.log("hello");',
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '匹配网址 (每行一个)',
                  border: OutlineInputBorder(),
                  hintText: '*://*.example.com/*',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSaved(
              UserScript(
                name: _nameCtrl.text,
                code: _codeCtrl.text,
                matches: _matchesCtrl.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList(),
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
