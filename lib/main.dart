import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final raw = await rootBundle.loadString('assets/data/prayers.json');
  final library = PrayerLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(library, prefs),
      child: const PrayerApp(),
    ),
  );
}

class PrayerCategory {
  final String id;
  final String name;
  final int order;
  const PrayerCategory({required this.id, required this.name, required this.order});

  factory PrayerCategory.fromJson(Map<String, dynamic> j) => PrayerCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        order: (j['order'] as num?)?.toInt() ?? 0,
      );
}

class Prayer {
  final String id;
  final String title;
  final String subtitle;
  final String tradition;
  final List<String> categoryIds;
  final List<String> tags;
  final String text;

  const Prayer({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tradition,
    required this.categoryIds,
    required this.tags,
    required this.text,
  });

  factory Prayer.fromJson(Map<String, dynamic> j) => Prayer(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        tradition: (j['tradition'] as String?) ?? '',
        categoryIds: List<String>.from(j['category_ids'] as List? ?? const []),
        tags: List<String>.from(j['tags'] as List? ?? const []),
        text: (j['text'] as Map<String, dynamic>)['vi'] as String,
      );
}

class PrayerLibrary {
  final List<PrayerCategory> categories;
  final List<Prayer> prayers;
  const PrayerLibrary({required this.categories, required this.prayers});

  factory PrayerLibrary.fromJson(Map<String, dynamic> j) {
    final cats = (j['categories'] as List)
        .map((e) => PrayerCategory.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final prayers = (j['prayers'] as List)
        .map((e) => Prayer.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrayerLibrary(categories: cats, prayers: prayers);
  }
}

// ---------------------------------------------------------------------------
// Vietnamese diacritic folding so "lay cha" finds "Lạy Cha"
// ---------------------------------------------------------------------------
const _diacritics = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _foldMap = {
  for (final e in _diacritics.entries)
    for (final ch in e.value.split('')) ch: e.key,
};

String fold(String input) =>
    input.toLowerCase().split('').map((c) => _foldMap[c] ?? c).join();

// ---------------------------------------------------------------------------
// App state (later: lib/presentation/providers/)
// ---------------------------------------------------------------------------
class AppState extends ChangeNotifier {
  AppState(this.library, this._prefs) {
    _favorites = (_prefs.getStringList('favorites') ?? const []).toSet();
    _dark = _prefs.getBool('dark') ?? false;
    _fontSize = _prefs.getDouble('fontSize') ?? 20;
  }

  final PrayerLibrary library;
  final SharedPreferences _prefs;

  late Set<String> _favorites;
  late bool _dark;
  late double _fontSize;

  bool get dark => _dark;
  double get fontSize => _fontSize;
  bool isFavorite(String id) => _favorites.contains(id);

  void toggleFavorite(String id) {
    _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    _prefs.setStringList('favorites', _favorites.toList());
    notifyListeners();
  }

  void toggleDark() {
    _dark = !_dark;
    _prefs.setBool('dark', _dark);
    notifyListeners();
  }

  void changeFontSize(double delta) {
    _fontSize = (_fontSize + delta).clamp(14, 36).toDouble();
    _prefs.setDouble('fontSize', _fontSize);
    notifyListeners();
  }

  /// Simple in-memory search. For a large library, move this to SQLite FTS5.
  List<Prayer> search({
    String query = '',
    String? categoryId,
    bool favoritesOnly = false,
  }) {
    final q = fold(query.trim());
    return library.prayers.where((p) {
      if (favoritesOnly && !_favorites.contains(p.id)) return false;
      if (categoryId != null && !p.categoryIds.contains(categoryId)) return false;
      if (q.isEmpty) return true;
      return fold('${p.title} ${p.subtitle} ${p.tags.join(' ')} ${p.text}')
          .contains(q);
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// App root (later: lib/app.dart + lib/core/theme/)
// ---------------------------------------------------------------------------
class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C6A3F),
          brightness: b,
        ),
        textTheme: GoogleFonts.beVietnamProTextTheme(
          ThemeData(brightness: b).textTheme,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppState, bool>((s) => s.dark);
    return MaterialApp(
      title: 'Kinh Nguyện',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const HomeShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Screens (later: lib/presentation/screens/)
// ---------------------------------------------------------------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          PrayerListPage(favoritesOnly: false),
          PrayerListPage(favoritesOnly: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Kinh',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Yêu thích',
          ),
        ],
      ),
    );
  }
}

class PrayerListPage extends StatefulWidget {
  final bool favoritesOnly;
  const PrayerListPage({super.key, required this.favoritesOnly});

  @override
  State<PrayerListPage> createState() => _PrayerListPageState();
}

class _PrayerListPageState extends State<PrayerListPage> {
  String _query = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final prayers = app.search(
      query: _query,
      categoryId: _categoryId,
      favoritesOnly: widget.favoritesOnly,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.favoritesOnly ? 'Yêu thích' : 'Kinh Nguyện'),
        actions: [
          IconButton(
            tooltip: app.dark ? 'Giao diện sáng' : 'Giao diện tối',
            icon: Icon(app.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: app.toggleDark,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Tìm kinh...',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Tất cả', _categoryId == null, () => setState(() => _categoryId = null)),
                for (final c in app.library.categories)
                  _chip(c.name, _categoryId == c.id, () => setState(() => _categoryId = c.id)),
              ],
            ),
          ),
          Expanded(
            child: prayers.isEmpty
                ? Center(
                    child: Text(
                      widget.favoritesOnly
                          ? 'Chưa có kinh yêu thích'
                          : 'Không tìm thấy kinh phù hợp',
                    ),
                  )
                : ListView.separated(
                    itemCount: prayers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = prayers[i];
                      return ListTile(
                        title: Text(p.title),
                        subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                        trailing: app.isFavorite(p.id)
                            ? const Icon(Icons.favorite, size: 20)
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrayerDetailPage(prayer: p),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class PrayerDetailPage extends StatelessWidget {
  final Prayer prayer;
  const PrayerDetailPage({super.key, required this.prayer});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fav = app.isFavorite(prayer.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(prayer.title),
        actions: [
          IconButton(
            tooltip: 'Giảm cỡ chữ',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => app.changeFontSize(-2),
          ),
          IconButton(
            tooltip: 'Tăng cỡ chữ',
            icon: const Icon(Icons.text_increase),
            onPressed: () => app.changeFontSize(2),
          ),
          IconButton(
            tooltip: fav ? 'Bỏ yêu thích' : 'Yêu thích',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => app.toggleFavorite(prayer.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prayer.subtitle.isNotEmpty) ...[
                Text(
                  prayer.subtitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
              ],
              SelectableText(
                prayer.text,
                style: GoogleFonts.notoSerif(fontSize: app.fontSize, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
