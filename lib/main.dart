import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotesApp());
}

// ── MODELS ──────────────────────────────────────────────
enum ItemType { note, todo, drawing }

class NoteItem {
  String id;
  String title;
  String content;
  ItemType type;
  bool pinned;
  bool isDark;
  DateTime createdAt;
  List<TodoEntry> todos;
  List<DrawPoint> drawPoints;

  NoteItem({
    required this.id,
    required this.title,
    this.content = '',
    required this.type,
    this.pinned = false,
    this.isDark = true,
    required this.createdAt,
    this.todos = const [],
    this.drawPoints = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'type': type.index,
    'pinned': pinned,
    'isDark': isDark,
    'createdAt': createdAt.toIso8601String(),
    'todos': todos.map((t) => t.toJson()).toList(),
    'drawPoints': drawPoints.map((d) => d.toJson()).toList(),
  };

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
    id: j['id'],
    title: j['title'],
    content: j['content'] ?? '',
    type: ItemType.values[j['type']],
    pinned: j['pinned'] ?? false,
    isDark: j['isDark'] ?? true,
    createdAt: DateTime.parse(j['createdAt']),
    todos: (j['todos'] as List? ?? []).map((t) => TodoEntry.fromJson(t)).toList(),
    drawPoints: (j['drawPoints'] as List? ?? []).map((d) => DrawPoint.fromJson(d)).toList(),
  );
}

class TodoEntry {
  String text;
  bool done;
  TodoEntry({required this.text, this.done = false});
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory TodoEntry.fromJson(Map<String, dynamic> j) => TodoEntry(text: j['text'], done: j['done'] ?? false);
}

class DrawPoint {
  double x, y;
  bool isNewStroke;
  DrawPoint({required this.x, required this.y, this.isNewStroke = false});
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'n': isNewStroke};
  factory DrawPoint.fromJson(Map<String, dynamic> j) => DrawPoint(x: j['x'].toDouble(), y: j['y'].toDouble(), isNewStroke: j['n'] ?? false);
}

// ── THEME ────────────────────────────────────────────────
const kBg = Color(0xFF0D0D0D);
const kSurface = Color(0xFF161616);
const kBorder = Color(0xFF252525);
const kText = Color(0xFFE8E2D9);
const kMuted = Color(0xFF666666);
const kAccent = Color(0xFFC8F060);
const kAccent2 = Color(0xFFF0A860);

// ── APP ──────────────────────────────────────────────────
class NotesApp extends StatefulWidget {
  const NotesApp({super.key});
  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? _darkTheme() : _lightTheme(),
      home: HomePage(
        isDarkMode: isDarkMode,
        onThemeToggle: () => setState(() => isDarkMode = !isDarkMode),
      ),
    );
  }

  ThemeData _darkTheme() => ThemeData(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurface),
    fontFamily: 'monospace',
  );

  ThemeData _lightTheme() => ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF0EDE6),
    colorScheme: const ColorScheme.light(primary: Color(0xFF2D5016), surface: Color(0xFFFAF8F4)),
    fontFamily: 'monospace',
  );
}

// ── HOME PAGE ────────────────────────────────────────────
class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  const HomePage({super.key, required this.isDarkMode, required this.onThemeToggle});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<NoteItem> items = [];
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notes') ?? [];
    setState(() {
      items = raw.map((s) => NoteItem.fromJson(json.decode(s))).toList();
    });
  }

  Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notes', items.map((i) => json.encode(i.toJson())).toList());
  }

  void deleteItem(String id) {
    setState(() => items.removeWhere((i) => i.id == id));
    saveItems();
  }

  void togglePin(String id) {
    setState(() {
      final item = items.firstWhere((i) => i.id == id);
      item.pinned = !item.pinned;
    });
    saveItems();
  }

  List<NoteItem> get filteredItems {
    final q = searchQuery.toLowerCase();
    final filtered = q.isEmpty
      ? items
      : items.where((i) => i.title.toLowerCase().contains(q) || i.content.toLowerCase().contains(q)).toList();
    return [
      ...filtered.where((i) => i.pinned),
      ...filtered.where((i) => !i.pinned),
    ];
  }

  void openItem(NoteItem? item, ItemType type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPage(item: item, type: type, isDarkMode: widget.isDarkMode)),
    );
    if (result != null) {
      setState(() {
        final idx = items.indexWhere((i) => i.id == result.id);
        if (idx >= 0) {
          items[idx] = result;
        } else {
          items.insert(0, result);
        }
      });
      saveItems();
    }
  }

  Color get bg => widget.isDarkMode ? kBg : const Color(0xFFF0EDE6);
  Color get surface => widget.isDarkMode ? kSurface : const Color(0xFFFAF8F4);
  Color get border => widget.isDarkMode ? kBorder : const Color(0xFFD8D4CC);
  Color get text => widget.isDarkMode ? kText : const Color(0xFF1A1A1A);
  Color get muted => widget.isDarkMode ? kMuted : const Color(0xFF777777);
  Color get accent => widget.isDarkMode ? kAccent : const Color(0xFF4A7C1F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('NOTES', style: TextStyle(fontSize: 11, letterSpacing: 6, color: accent)),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onThemeToggle,
                    child: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: muted, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: text, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: muted, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: muted, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Add buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _addBtn('+ NOTE', () => openItem(null, ItemType.note)),
                  const SizedBox(width: 8),
                  _addBtn('+ TODO', () => openItem(null, ItemType.todo)),
                  const SizedBox(width: 8),
                  _addBtn('+ DRAW', () => openItem(null, ItemType.drawing)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items list
            Expanded(
              child: filteredItems.isEmpty
                ? Center(child: Text('No notes yet', style: TextStyle(color: muted, fontSize: 12, letterSpacing: 2)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredItems.length,
                    itemBuilder: (_, i) => _buildCard(filteredItems[i]),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(4),
          color: accent.withOpacity(0.08),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: accent, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildCard(NoteItem item) {
    return GestureDetector(
      onTap: () => openItem(item, item.type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: item.pinned ? accent.withOpacity(0.4) : border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    item.type == ItemType.note ? 'NOTE' : item.type == ItemType.todo ? 'TODO' : 'DRAW',
                    style: TextStyle(fontSize: 8, color: muted, letterSpacing: 1),
                  ),
                ),
                if (item.pinned) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.push_pin, size: 12, color: accent),
                ],
                const Spacer(),
                Text(DateFormat('MMM d').format(item.createdAt), style: TextStyle(fontSize: 10, color: muted)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => togglePin(item.id),
                  child: Icon(item.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 16, color: muted),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(item.id),
                  child: Icon(Icons.delete_outline, size: 16, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title.isEmpty ? 'Untitled' : item.title,
              style: TextStyle(fontSize: 14, color: text, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.type == ItemType.note && item.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.content, style: TextStyle(fontSize: 11, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (item.type == ItemType.todo && item.todos.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...item.todos.take(3).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(t.done ? Icons.check_box : Icons.check_box_outline_blank, size: 12, color: t.done ? accent : muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t.text, style: TextStyle(fontSize: 11, color: t.done ? muted : text, decoration: t.done ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
              if (item.todos.length > 3)
                Text('+${item.todos.length - 3} more', style: TextStyle(fontSize: 10, color: muted)),
            ],
            if (item.type == ItemType.drawing) ...[
              const SizedBox(height: 8),
              Container(
                height: 60,
                decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(2)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CustomPaint(painter: DrawPreviewPainter(item.drawPoints)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        title: Text('Delete?', style: TextStyle(color: text, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: muted))),
          TextButton(onPressed: () { Navigator.pop(context); deleteItem(id); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ── EDIT PAGE ────────────────────────────────────────────
class EditPage extends StatefulWidget {
  final NoteItem? item;
  final ItemType type;
  final bool isDarkMode;
  const EditPage({super.key, this.item, required this.type, required this.isDarkMode});
  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController titleCtrl;
  late TextEditingController contentCtrl;
  late List<TodoEntry> todos;
  late List<DrawPoint> drawPoints;
  final newTodoCtrl = TextEditingController();
  final _drawKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.item?.title ?? '');
    contentCtrl = TextEditingController(text: widget.item?.content ?? '');
    todos = List.from(widget.item?.todos ?? []);
    drawPoints = List.from(widget.item?.drawPoints ?? []);
  }

  NoteItem get result => NoteItem(
    id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: titleCtrl.text,
    content: contentCtrl.text,
    type: widget.item?.type ?? widget.type,
    pinned: widget.item?.pinned ?? false,
    isDark: widget.isDarkMode,
    createdAt: widget.item?.createdAt ?? DateTime.now(),
    todos: todos,
    drawPoints: drawPoints,
  );

  Color get bg => widget.isDarkMode ? kBg : const Color(0xFFF0EDE6);
  Color get surface => widget.isDarkMode ? kSurface : const Color(0xFFFAF8F4);
  Color get border => widget.isDarkMode ? kBorder : const Color(0xFFD8D4CC);
  Color get text => widget.isDarkMode ? kText : const Color(0xFF1A1A1A);
  Color get muted => widget.isDarkMode ? kMuted : const Color(0xFF777777);
  Color get accent => widget.isDarkMode ? kAccent : const Color(0xFF4A7C1F);

  @override
  Widget build(BuildContext context) {
    final type = widget.item?.type ?? widget.type;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, result),
                    child: Icon(Icons.arrow_back, color: muted, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Title...',
                        hintStyle: TextStyle(color: muted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, result),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                      child: Text('SAVE', style: TextStyle(fontSize: 10, color: widget.isDarkMode ? kBg : Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: border, height: 1),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: type == ItemType.note
                  ? _buildNote()
                  : type == ItemType.todo
                  ? _buildTodo()
                  : _buildDraw(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNote() {
    return TextField(
      controller: contentCtrl,
      style: TextStyle(color: text, fontSize: 13, height: 1.8),
      maxLines: null,
      expands: true,
      decoration: InputDecoration(
        hintText: 'Start writing...',
        hintStyle: TextStyle(color: muted),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildTodo() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newTodoCtrl,
                style: TextStyle(color: text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add item...',
                  hintStyle: TextStyle(color: muted),
                  border: InputBorder.none,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    setState(() { todos.add(TodoEntry(text: v.trim())); newTodoCtrl.clear(); });
                  }
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                if (newTodoCtrl.text.trim().isNotEmpty) {
                  setState(() { todos.add(TodoEntry(text: newTodoCtrl.text.trim())); newTodoCtrl.clear(); });
                }
              },
              child: Icon(Icons.add, color: accent, size: 20),
            ),
          ],
        ),
        Divider(color: border),
        Expanded(
          child: ListView.builder(
            itemCount: todos.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => todos[i].done = !todos[i].done),
                    child: Icon(
                      todos[i].done ? Icons.check_box : Icons.check_box_outline_blank,
                      color: todos[i].done ? accent : muted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      todos[i].text,
                      style: TextStyle(
                        fontSize: 13,
                        color: todos[i].done ? muted : text,
                        decoration: todos[i].done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => todos.removeAt(i)),
                    child: Icon(Icons.close, color: muted, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraw() {
    return Column(
      children: [
        Row(
          children: [
            Text('DRAW', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => drawPoints.clear()),
              child: Text('CLEAR', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 2)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            key: _drawKey,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF111111) : Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: GestureDetector(
              onPanStart: (d) {
                final box = _drawKey.currentContext!.findRenderObject() as RenderBox;
                final local = box.globalToLocal(d.globalPosition);
                setState(() => drawPoints.add(DrawPoint(x: local.dx, y: local.dy, isNewStroke: true)));
              },
              onPanUpdate: (d) {
                final box = _drawKey.currentContext!.findRenderObject() as RenderBox;
                final local = box.globalToLocal(d.globalPosition);
                setState(() => drawPoints.add(DrawPoint(x: local.dx, y: local.dy)));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CustomPaint(
                  painter: DrawPainter(drawPoints, accent),
                  child: Container(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── PAINTERS ─────────────────────────────────────────────
class DrawPainter extends CustomPainter {
  final List<DrawPoint> points;
  final Color color;
  DrawPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < points.length; i++) {
      if (!points[i].isNewStroke) {
        canvas.drawLine(
          Offset(points[i-1].x, points[i-1].y),
          Offset(points[i].x, points[i].y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrawPainter old) => true;
}

class DrawPreviewPainter extends CustomPainter {
  final List<DrawPoint> points;
  DrawPreviewPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final xs = points.map((p) => p.x).toList();
    final ys = points.map((p) => p.y).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final scaleX = maxX > minX ? size.width / (maxX - minX) : 1.0;
    final scaleY = maxY > minY ? size.height / (maxY - minY) : 1.0;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9;

    final paint = Paint()
      ..color = kAccent
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < points.length; i++) {
      if (!points[i].isNewStroke) {
        canvas.drawLine(
          Offset((points[i-1].x - minX) * scale + 4, (points[i-1].y - minY) * scale + 4),
          Offset((points[i].x - minX) * scale + 4, (points[i].y - minY) * scale + 4),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrawPreviewPainter old) => true;
}