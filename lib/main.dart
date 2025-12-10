import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

// Global locale notifier ("vi" or "en"). Initialized in main().
late ValueNotifier<String> gLocaleNotifier;

/// Convenience translator that returns the Vietnamese or English text based
/// on the current global locale.
String t(String vi, String en) => gLocaleNotifier.value == 'vi' ? vi : en;

/// Toggle the global locale and persist to SharedPreferences.
Future<void> toggleLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final next = gLocaleNotifier.value == 'vi' ? 'en' : 'vi';
  await prefs.setString('locale', next);
  gLocaleNotifier.value = next;
}

// Global audio player and helper to play note assets by index.
final AudioPlayer _globalAudioPlayer = AudioPlayer();

Future<void> playNoteAssetByIndex(int index) async {
  if (index < 0 || index >= notes.length) return;
  final note = notes[index];
  final asset = 'audio/${note.international}4.wav'; // corresponds to assets/audio/C4.wav
  try {
    await _globalAudioPlayer.stop();
    await _globalAudioPlayer.play(AssetSource(asset));
  } catch (e) {
    // log error for debugging
    print('Audio playback error: $e');
  }
}

// Shared helper to create multiple-choice option indices.
List<int> makeOptionsRandom(int correct, Random rnd, {int count = 4}) {
  final set = <int>{correct};
  while (set.length < count) set.add(rnd.nextInt(notes.length));
  final list = set.toList()..shuffle(rnd);
  return list;
}

/// Entry point of the application.
///
/// This app provides three modes to help memorize musical notes:
/// 1. A flash‑card style learner for mapping the
///    international note names (C–D–E–F–G–A–B) to their solfège equivalents
///    (Do–Re–Mi–Fa–Sol–La–Si).
/// 2. A match mode where the user must pick the correct key on a
///    simplified piano keyboard corresponding to the displayed note.
/// 3. A test mode that asks the user to quickly identify notes and tracks
///    performance over several rounds. The design is deliberately
///    minimalistic, using large buttons and clear typography to remain
///    approachable for children and new learners.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('locale') ?? 'vi';
  gLocaleNotifier = ValueNotifier<String>(saved);

  runApp(ValueListenableBuilder<String>(
    valueListenable: gLocaleNotifier,
    builder: (context, locale, _) => NoteFlashcardApp(locale: locale),
  ));
}

/// Root widget of the flashcard application.
class NoteFlashcardApp extends StatelessWidget {
  final String locale;

  const NoteFlashcardApp({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Flashcards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use Material3 for a more modern look.
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      // Use a ValueKey derived from the locale so HomeScreen is recreated
      // whenever the locale changes and all t(...) calls are re-evaluated.
      home: HomeScreen(key: ValueKey(locale)),
      onGenerateRoute: (settings) {
        if (settings.name == '/leaderboard') {
          return MaterialPageRoute(
            builder: (context) => const LeaderboardPage(),
            settings: settings,
          );
        }
        if (settings.name == '/about') {
          return MaterialPageRoute(
            builder: (context) => const AboutPage(),
            settings: settings,
          );
        }
        if (settings.name == '/contact') {
          return MaterialPageRoute(
            builder: (context) => const ContactPage(),
            settings: settings,
          );
        }
        if (settings.name == '/privacy') {
          return MaterialPageRoute(
            builder: (context) => const PrivacyPolicyPage(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

/// Main home screen that hosts bottom navigation for different modes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Lazy initialize pages so state is preserved between tabs.
  late final List<Widget> _pages = [
    const LearnPage(),
    const MatchPage(),
    const TestPage(),
    const ProgressPage(),
    const LeaderboardPage(),
  ];
  // Note: locale is handled globally via gLocaleNotifier and helper t().

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: toggleLocale,
        icon: const Icon(Icons.language),
        label: Text(gLocaleNotifier.value == 'vi' ? 'VI' : 'EN'),
        tooltip: t('Chuyển sang English', 'Switch to Vietnamese'),
      ),
      drawer: _buildDrawer(context),
      body: _pages[_selectedIndex],
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.school_outlined),
                  label: t('Học nốt', 'Learn'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.piano),
                  label: t('Match', 'Match'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.quiz_outlined),
                  label: t('Test', 'Test'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up),
                  label: t('Tiến bộ', 'Progress'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events),
                  label: t('Xếp hạng', 'Leaderboard'),
                ),
              ],
            )
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  label: t('Học nốt nhạc', 'Learn'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.piano),
                  label: t('Match nốt với phím', 'Match'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.quiz_outlined),
                  label: t('Kiểm tra', 'Test'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.trending_up),
                  label: t('Tiến bộ', 'Progress'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events),
                  label: t('Bảng xếp hạng', 'Leaderboard'),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.piano,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  t('Piano Flashcards', 'Piano Flashcards'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text(t('Về ứng dụng', 'About')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about');
            },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text(t('Liên hệ', 'Contact')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/contact');
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text(t('Chính sách bảo mật', 'Privacy Policy')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/privacy');
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text(t('Thoát', 'Exit')),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Data class representing a musical note and its corresponding solfège.
class Note {
  final String international;
  final String solfege;

  const Note(this.international, this.solfege);
}

/// Test result with detailed scoring per category
class TestResult {
  final String playerName;
  final int totalScore;
  final int audioScore;
  final int solfegeScore;
  final int keyScore;
  final int staffScore;
  final DateTime timestamp;
  final TestMode mode;

  TestResult({
    required this.playerName,
    required this.totalScore,
    required this.audioScore,
    required this.solfegeScore,
    required this.keyScore,
  required this.staffScore,
    required this.timestamp,
    required this.mode,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'totalScore': totalScore,
        'audioScore': audioScore,
        'solfegeScore': solfegeScore,
        'keyScore': keyScore,
    'staffScore': staffScore,
        'timestamp': timestamp.toIso8601String(),
        'mode': mode.toString(),
      };

  // Create from JSON
  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
        playerName: json['playerName'] as String,
        totalScore: json['totalScore'] as int,
        audioScore: json['audioScore'] as int,
        solfegeScore: json['solfegeScore'] as int,
        keyScore: json['keyScore'] as int,
    staffScore: (json['staffScore'] as int?) ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
        mode: TestMode.values
            .firstWhere((e) => e.toString() == json['mode'] as String),
      );
}

/// Leaderboard entry with rank
class LeaderboardEntry {
  final int rank;
  final TestResult result;
  final double accuracy;

  LeaderboardEntry({
    required this.rank,
    required this.result,
    required this.accuracy,
  });
}

/// Daily progress tracking - store one entry per day
class DailyProgress {
  final DateTime date;
  final int testsCompleted; // Number of tests done today
  final int averageScore; // Average score across all tests today
  final int bestScore; // Best score today
  final Map<String, int> categoryScores; // Score by test mode (audioToNote, solfegeToIntl, etc)

  DailyProgress({
    required this.date,
    required this.testsCompleted,
    required this.averageScore,
    required this.bestScore,
    required this.categoryScores,
  });

  // Get date string in format YYYY-MM-DD for storage key
  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'testsCompleted': testsCompleted,
    'averageScore': averageScore,
    'bestScore': bestScore,
    'categoryScores': categoryScores,
  };

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
    date: DateTime.parse(json['date'] as String),
    testsCompleted: json['testsCompleted'] as int,
    averageScore: json['averageScore'] as int,
    bestScore: json['bestScore'] as int,
    categoryScores: Map<String, int>.from(json['categoryScores'] as Map? ?? {}),
  );
}

/// Category progress - track performance by test mode
class CategoryProgress {
  final String categoryName; // audioToNote, solfegeToIntl, etc
  final int totalTests; // Total tests in this category
  final int averageScore; // Average score across all tests in category
  final int bestScore; // Best score in this category
  final List<int> last7Days; // Last 7 days scores for trending

  CategoryProgress({
    required this.categoryName,
    required this.totalTests,
    required this.averageScore,
    required this.bestScore,
    required this.last7Days,
  });

  Map<String, dynamic> toJson() => {
    'categoryName': categoryName,
    'totalTests': totalTests,
    'averageScore': averageScore,
    'bestScore': bestScore,
    'last7Days': last7Days,
  };

  factory CategoryProgress.fromJson(Map<String, dynamic> json) => CategoryProgress(
    categoryName: json['categoryName'] as String,
    totalTests: json['totalTests'] as int,
    averageScore: json['averageScore'] as int,
    bestScore: json['bestScore'] as int,
    last7Days: List<int>.from(json['last7Days'] as List? ?? []),
  );
}

/// Helper class to manage progress tracking data
class ProgressTracker {
  late SharedPreferences _prefs;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save or update today's progress when a test is completed
  Future<void> recordTestResult(TestResult result) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    // Get existing daily progress
    final existingJson = _prefs.getString('daily_progress_$dateKey');
    DailyProgress dailyProgress;
    
    if (existingJson != null) {
      dailyProgress = DailyProgress.fromJson(jsonDecode(existingJson) as Map<String, dynamic>);
    } else {
      dailyProgress = DailyProgress(
        date: today,
        testsCompleted: 0,
        averageScore: 0,
        bestScore: 0,
        categoryScores: {},
      );
    }
    
    // Update daily progress
    final newTestCount = dailyProgress.testsCompleted + 1;
    final newAverageScore = ((dailyProgress.averageScore * dailyProgress.testsCompleted) + result.totalScore) ~/ newTestCount;
    final newBestScore = max(dailyProgress.bestScore, result.totalScore);
    
    // Update category score
    final modeKey = _getModeName(result.mode);
    final currentCategoryScore = dailyProgress.categoryScores[modeKey] ?? 0;
    final newCategoryScore = ((currentCategoryScore * dailyProgress.categoryScores.length) + result.totalScore) ~/ (dailyProgress.categoryScores.length + 1);
    
    final updatedCategoryScores = {...dailyProgress.categoryScores};
    updatedCategoryScores[modeKey] = newCategoryScore;
    
    final updatedDaily = DailyProgress(
      date: today,
      testsCompleted: newTestCount,
      averageScore: newAverageScore,
      bestScore: newBestScore,
      categoryScores: updatedCategoryScores,
    );
    
    // Save to SharedPreferences
    await _prefs.setString('daily_progress_$dateKey', jsonEncode(updatedDaily.toJson()));
  }

  /// Get progress for last N days
  Future<List<DailyProgress>> getLast7DaysProgress() async {
    final results = <DailyProgress>[];
    final now = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final json = _prefs.getString('daily_progress_$dateKey');
      
      if (json != null) {
        results.add(DailyProgress.fromJson(jsonDecode(json) as Map<String, dynamic>));
      }
    }
    
    return results.reversed.toList();
  }

  /// Get category progress summary
  Future<List<CategoryProgress>> getCategoryProgress(List<TestResult> allResults) async {
    final categoryMap = <String, List<int>>{};
    
    // Group results by category
    for (final result in allResults) {
      final modeKey = _getModeName(result.mode);
      categoryMap.putIfAbsent(modeKey, () => []);
      categoryMap[modeKey]!.add(result.totalScore);
    }
    
    // Calculate stats for each category
    final categoryProgress = <CategoryProgress>[];
    categoryMap.forEach((modeKey, scores) {
      if (scores.isNotEmpty) {
        final avg = scores.reduce((a, b) => a + b) ~/ scores.length;
        final best = scores.reduce(max);
        
        // Get last 7 days of this category
        final last7 = <int>[];
        final now = DateTime.now();
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final json = _prefs.getString('daily_progress_$dateKey');
          if (json != null) {
            final daily = DailyProgress.fromJson(jsonDecode(json) as Map<String, dynamic>);
            final score = daily.categoryScores[modeKey] ?? 0;
            if (score > 0) last7.add(score);
          }
        }
        
        categoryProgress.add(CategoryProgress(
          categoryName: _getModeLabel(modeKey),
          totalTests: scores.length,
          averageScore: avg,
          bestScore: best,
          last7Days: last7.reversed.toList(),
        ));
      }
    });
    
    return categoryProgress;
  }

  String _getModeName(TestMode mode) {
    switch (mode) {
      case TestMode.audioToNote:
        return 'audio';
      case TestMode.solfegeToIntl:
        return 'solfege';
      case TestMode.intlToKey:
        return 'key';
      case TestMode.staffNotation:
        return 'staff';
      case TestMode.mixed:
        return 'mixed';
    }
  }

  String _getModeLabel(String modeKey) {
    switch (modeKey) {
      case 'audio':
        return t('🎵 Nghe', '🎵 Audio');
      case 'solfege':
        return t('🎼 Solfège', '🎼 Solfège');
      case 'key':
        return t('⌨️ Phím', '⌨️ Key');
      case 'staff':
        return t('🎼 Khuông nhạc', '🎼 Staff');
      case 'mixed':
        return t('🎲 Trộn lẫn', '🎲 Mixed');
      default:
        return modeKey;
    }
  }
}

/// Static list of supported notes. The order follows ascending pitch from C to B.
const List<Note> notes = [
  Note('C', 'Do'),
  Note('D', 'Re'),
  Note('E', 'Mi'),
  Note('F', 'Fa'),
  Note('G', 'Sol'),
  Note('A', 'La'),
  Note('B', 'Si'),
];

/// Musical staff widget for displaying notes on a 5-line staff
class MusicalStaff extends StatefulWidget {
  final int noteIndex; // Index in notes list (0-6)
  final Color staffColor;
  final Color noteColor;
  /// Whether the label should be initially visible. Default false (hidden).
  final bool initiallyShowNoteLabel;

  const MusicalStaff({
    super.key,
    required this.noteIndex,
    this.initiallyShowNoteLabel = false,
    this.staffColor = Colors.black,
    this.noteColor = Colors.black,
  });

  @override
  State<MusicalStaff> createState() => _MusicalStaffState();
}

class _MusicalStaffState extends State<MusicalStaff> {
  late bool _showLabel;

  @override
  void initState() {
    super.initState();
    _showLabel = widget.initiallyShowNoteLabel;
  }

  void _toggleLabel() {
    setState(() {
      _showLabel = !_showLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ensure we have finite dimensions for CustomPaint
            final width = (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width - 32;
            final height = (constraints.maxHeight.isFinite && constraints.maxHeight > 0)
                ? constraints.maxHeight
                : 180.0;

            return SizedBox(
              width: width,
              height: height,
              child: CustomPaint(
                painter: StaffPainter(
                  noteIndex: widget.noteIndex,
                  showNoteLabel: _showLabel,
                  staffColor: widget.staffColor,
                  noteColor: widget.noteColor,
                ),
                size: Size(width, height),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter to draw musical staff with notes
class StaffPainter extends CustomPainter {
  final int noteIndex;
  final bool showNoteLabel;
  final Color staffColor;
  final Color noteColor;

  StaffPainter({
    required this.noteIndex,
    required this.showNoteLabel,
    required this.staffColor,
    required this.noteColor,
  });

  // Note positions: C D E F G A B
  // Staff lines (from top): 0, 1, 2, 3, 4
  // Spaces (from top): 0.5, 1.5, 2.5, 3.5, 4.5
  // Each note occupies different positions
  // C: 4.5 (space below bottom line)
  // D: 4 (bottom line)
  // E: 3.5 (space)
  // F: 3 (line)
  // G: 2.5 (space)
  // A: 2 (line)
  // B: 1.5 (space)
  
  static const List<double> notePositions = [
    5.0, // C (shifted down one step)
    4.5, // D
    4.0, // E (Mi) -> bottom line
    3.5, // F (Fa) -> space between line 1 and 2 from bottom
    3.0, // G
    2.5, // A
    2.0, // B (Si) -> third line from bottom
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = staffColor
      ..strokeWidth = 2;
    // Ensure we use the provided finite height; fall back to a sensible default
    final availableHeight = (size.height.isFinite && size.height > 0) ? size.height : 180.0;
    final availableWidth = (size.width.isFinite && size.width > 0) ? size.width : 300.0;

    // Padding inside the paintable area
    final horizontalPadding = availableWidth * 0.04; // 4%
    final verticalPadding = availableHeight * 0.12; // 12% top/bottom padding

    const lineCount = 5;
    // Compute line spacing so the 5 lines fit between top and bottom padding
    final usableHeight = availableHeight - (verticalPadding * 2);
    // Scale staff down by 0.75 (25% smaller) to fit better in card on all screen sizes
    final lineSpacing = (usableHeight / (lineCount - 1)) * 0.75;

    // Draw staff lines (5 horizontal lines)
    for (int i = 0; i < lineCount; i++) {
      final y = verticalPadding + (i * lineSpacing);
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(availableWidth - horizontalPadding, y),
        paint,
      );
    }

    // Draw note
    final noteY = verticalPadding + (notePositions[noteIndex] * (lineSpacing / 1.0));
    final noteX = availableWidth / 2;
    final noteRadius = lineSpacing * 0.45; // note slightly less than half spacing

    // Note head (filled circle)
    final notePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(noteX, noteY), noteRadius, notePaint);

    // Note stem
    final stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = 2;

    final stemX = noteX + noteRadius + 2;
    final stemEndY = noteY - (lineSpacing * 2.8);
    canvas.drawLine(
      Offset(stemX, noteY),
      Offset(stemX, stemEndY),
      stemPaint,
    );

    // Draw note label if needed
    if (showNoteLabel) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: notes[noteIndex].international,
          style: TextStyle(
            color: Colors.black,
            fontSize: (lineSpacing * 0.9).clamp(12.0, 28.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      // Place label left aligned, vertically centered on the note
      textPainter.paint(
        canvas,
        Offset(horizontalPadding / 2, noteY - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(StaffPainter oldDelegate) {
    return oldDelegate.noteIndex != noteIndex ||
        oldDelegate.staffColor != staffColor ||
        oldDelegate.noteColor != noteColor;
  }
}

/// A page allowing the user to learn the notes via flashcards.
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  final Random _random = Random();
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _listenMode = false;
  List<int> _learnOptions = [];
  String? _learnFeedback;
  bool _useStaffNotation = false; // Toggle between flashcard and staff

  void _nextCard() {
    setState(() {
      // Choose a random index different from current when possible.
      if (notes.length <= 1) {
        _currentIndex = 0;
      } else {
        int next;
        do {
          next = _random.nextInt(notes.length);
        } while (next == _currentIndex);
        _currentIndex = next;
      }
      _showAnswer = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // start with a random card
    _currentIndex = _random.nextInt(notes.length);
  }

  void _startListenMode() {
    setState(() {
      _listenMode = true;
      _learnFeedback = null;
      _learnOptions = makeOptionsRandom(_currentIndex, _random);
    });
  }

  void _stopListenMode() {
    setState(() {
      _listenMode = false;
      _learnFeedback = null;
    });
  }

  // Play the piano sample for the current note from assets.
  Future<void> _playCurrentNote() async {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
    });

    // Map note international names to asset filenames.
    const noteToAsset = {
      'C': 'assets/audio/C4.wav',
      'D': 'assets/audio/D4.wav',
      'E': 'assets/audio/E4.wav',
      'F': 'assets/audio/F4.wav',
      'G': 'assets/audio/G4.wav',
      'A': 'assets/audio/A4.wav',
      'B': 'assets/audio/B4.wav',
    };

    final note = notes[_currentIndex];
    final assetPath = noteToAsset[note.international];
    try {
      if (assetPath != null) {
        // audioplayers can play from asset bundle by using AssetSource
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      }
    } catch (e) {
      // ignore errors for now
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  // No synthesized WAV helper needed; we play asset WAV samples via audioplayers.

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentNote = notes[_currentIndex];
    final isMobile = MediaQuery.of(context).size.width < 768;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 8.0 : 12.0;
    final cardFontSize = isMobile ? 48.0 : 64.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    final cardHeight = isMobile ? screenHeight * 0.35 : 250.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Học nốt nhạc',
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                // Toggle between flashcard and staff notation
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: !_useStaffNotation ? null : () {
                          setState(() => _useStaffNotation = false);
                        },
                        child: Text(
                          '🎴',
                          style: TextStyle(
                            fontSize: 18,
                            color: !_useStaffNotation ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _useStaffNotation ? null : () {
                          setState(() => _useStaffNotation = true);
                        },
                        child: Text(
                          '🎼',
                          style: TextStyle(
                            fontSize: 18,
                            color: _useStaffNotation ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: verticalPadding),
            // Flashcard or Staff notation container
            SizedBox(
              height: cardHeight,
              child: _useStaffNotation
                  ? Card(
                      elevation: 4,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isMobile)
                              SizedBox(
                                height: cardHeight * 0.7,
                                child: MusicalStaff(
                                  noteIndex: _currentIndex,
                                ),
                              )
                            else
                              Expanded(
                                child: MusicalStaff(
                                  noteIndex: _currentIndex,
                                ),
                              ),
                            if (_showAnswer)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                    '${currentNote.international} (${currentNote.solfege})',
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _listenMode ? null : _toggleAnswer,
                      child: Card(
                        elevation: 4,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: _showAnswer
                                ? Text(
                                    currentNote.solfege,
                                    key: ValueKey<bool>(_showAnswer),
                                    style: TextStyle(
                                      fontSize: cardFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Text(
                                    currentNote.international,
                                    key: ValueKey<bool>(_showAnswer),
                                    style: TextStyle(
                                      fontSize: cardFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(height: verticalPadding),
            // Instruction text
            Text(
              _useStaffNotation
                  ? t('Chạm để xem tên nốt', 'Tap to view note name')
                  : (_showAnswer ? t('Chạm vào thẻ để xem tên nốt', 'Tap the card to view note name') : t('Chạm vào thẻ để xem tên solfège', 'Tap the card to view solfège name')),
              style: TextStyle(fontSize: isMobile ? 14 : 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: verticalPadding),
            // Responsive button layout
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleAnswer,
                          icon: const Icon(Icons.flip),
                          label: Text(_showAnswer ? t('Ẩn', 'Hide') : t('Hiện', 'Show')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _nextCard,
                          icon: const Icon(Icons.navigate_next),
                          label: Text(t('Tiếp', 'Next')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlaying ? null : _playCurrentNote,
                          icon: const Icon(Icons.volume_up),
                          label: Text(_isPlaying ? t('Phát...', "Playing...") : t('Nghe', 'Listen')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _listenMode ? _stopListenMode : _startListenMode,
                          icon: const Icon(Icons.hearing),
                          label: Text(_listenMode ? t('Thoát', 'Exit') : t('Chọn', 'Choose')),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleAnswer,
                    icon: const Icon(Icons.flip),
                    label: Text(_showAnswer ? t('Ẩn', 'Hide') : t('Hiện', 'Show')),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _nextCard,
                    icon: const Icon(Icons.navigate_next),
                    label: Text(t('Tiếp theo', 'Next')),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isPlaying ? null : _playCurrentNote,
                    icon: const Icon(Icons.volume_up),
                    label: Text(_isPlaying ? t('Đang phát...', 'Playing...') : t('Nghe', 'Listen')),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _listenMode ? _stopListenMode : _startListenMode,
                    icon: const Icon(Icons.hearing),
                    label: Text(_listenMode ? t('Thoát nghe', 'Exit listening') : t('Nghe & Chọn', 'Listen & Choose')),
                  ),
                ],
              ),
            SizedBox(height: verticalPadding),
            // If in listen-and-choose mode, show choices
            if (_listenMode)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: FilledButton.icon(
                          onPressed: () => playNoteAssetByIndex(_currentIndex),
                          icon: const Icon(Icons.volume_up),
                          label: Text(t('Nghe nốt', 'Play note')),
                        ),
                      ),
                      SizedBox(height: verticalPadding),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(_learnOptions.length, (i) {
                          final idx = _learnOptions[i];
                          return ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (idx == _currentIndex) {
                                  _learnFeedback = 'correct';
                                } else {
                                  _learnFeedback = 'wrong';
                                }
                                // play selection sound
                                playNoteAssetByIndex(idx);
                              });
                            },
                            child: Text(notes[idx].international),
                          );
                        }),
                      ),
                      if (_learnFeedback != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Center(
                            child: Text(
                              _learnFeedback == 'correct' ? t('Đúng!', 'Correct!') : t('Sai', 'Wrong'),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _learnFeedback == 'correct' ? Colors.green : Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget representing a row of seven simplified piano keys.
class PianoKeys extends StatefulWidget {
  /// Callback when the user taps a key. The index corresponds to
  /// the position in the [notes] list.
  final ValueChanged<int> onKeyTapped;
  /// Optionally highlight a key. If null, no key is highlighted.
  final int? highlightedIndex;

  const PianoKeys({super.key, required this.onKeyTapped, this.highlightedIndex});

  @override
  State<PianoKeys> createState() => _PianoKeysState();
}

class _PianoKeysState extends State<PianoKeys> {
  // Map QWERTYU -> indices 0..6
  static const _keyMapLabel = {
    'q': 0,
    'w': 1,
    'e': 2,
    'r': 3,
    't': 4,
    'y': 5,
    'u': 6,
  };

  // QWERTY display labels
  static const _qwertyLabels = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U'];

  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-request focus so keyboard works when this widget is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final label = event.logicalKey.keyLabel.toLowerCase();
      final mapped = _keyMapLabel[label];
      if (mapped != null) {
        widget.onKeyTapped(mapped);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final keyHeight = isMobile ? 100.0 : 120.0;
    final fontSize = isMobile ? 8.0 : 10.0;
    
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final whiteKeyWidth = constraints.maxWidth / notes.length;
          return SizedBox(
            height: keyHeight,
            child: Stack(
              children: [
                // White keys
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(notes.length, (index) {
                    final isHighlighted = widget.highlightedIndex == index;
                    return GestureDetector(
                      onTap: () => widget.onKeyTapped(index),
                      child: Container(
                        width: whiteKeyWidth - 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: keyHeight,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: isHighlighted ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4.0, right: 4.0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              _qwertyLabels[index],
                              style: TextStyle(fontSize: fontSize, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                // Black keys overlay (simple positions between certain whites)
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(notes.length, (index) {
                      // place black keys between white keys for C-D, D-E, F-G, G-A, A-B
                      final hasBlack = index != 2 && index != 6; // E (2) and B (6) have no black key after
                      if (!hasBlack) {
                        return SizedBox(width: whiteKeyWidth);
                      }
                      final blackKey = GestureDetector(
                        onTap: () => widget.onKeyTapped(index),
                        child: Container(
                          width: (whiteKeyWidth - 8) / 2,
                          margin: EdgeInsets.only(left: whiteKeyWidth / 2 - ((whiteKeyWidth - 8) / 4)),
                          height: keyHeight * 0.67,
                          decoration: BoxDecoration(
                            color: widget.highlightedIndex == index ? Colors.grey[800] : Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                      return SizedBox(
                        width: whiteKeyWidth,
                        child: Align(alignment: Alignment.topCenter, child: blackKey),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Page where the user matches a note name to the corresponding piano key.
class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  late int _currentNoteIndex;
  String? _feedback;
  int? _selectedIndex;
  final Random _random = Random();


  @override
  void initState() {
    super.initState();
    _generateNewNote();
  }

  void _generateNewNote() {
    setState(() {
      // Choose a random note index between 0 and notes.length - 1.
      _currentNoteIndex = _random.nextInt(notes.length);
      _feedback = null;
      _selectedIndex = null;
    });
  }

  void _handleKeyTap(int index) {
    setState(() {
      _selectedIndex = index;
      // play the sound for the tapped key
      playNoteAssetByIndex(index);
      if (index == _currentNoteIndex) {
        _feedback = 'correct';
      } else {
        _feedback = 'wrong';    
      }
    });
    Future.delayed(const Duration(seconds: 1), () {
      _generateNewNote();
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = notes[_currentNoteIndex];
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    final noteFontSize = isMobile ? 36.0 : 48.0;
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Match nốt với phím', 'Match note to key'),
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: verticalPadding),
              // Display the note to match
              Text(
                t('Hãy chọn phím tương ứng với nốt:', 'Choose the key corresponding to the note:'),
                style: TextStyle(fontSize: isMobile ? 16 : 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  '${note.solfege}/${note.international}',
                  style: TextStyle(fontSize: noteFontSize, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: verticalPadding * 1.5),
              PianoKeys(
                highlightedIndex: _selectedIndex,
                onKeyTapped: _handleKeyTap,
              ),
              SizedBox(height: verticalPadding),
              if (_feedback != null)
                Center(
                  child: Text(
                    _feedback == 'correct' ? t('Chính xác!', 'Correct!') : t('Sai rồi :(', 'Wrong :('),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _feedback == 'correct' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page that administers a short test to gauge the user's recall speed.
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

enum TestMode { mixed, audioToNote, solfegeToIntl, intlToKey, staffNotation }

class Question {
  final int noteIndex;
  final TestMode mode;
  Question(this.noteIndex, this.mode);
}

class _TestPageState extends State<TestPage> {
  // default test settings
  TestMode _mode = TestMode.mixed;
  int _totalQuestions = 100; // mixed default
  int _currentQuestion = 0;
  List<Question> _questions = [];
  int _score = 0;
  int _audioScore = 0;
  int _solfegeScore = 0;
  int _keyScore = 0;
  int _staffScore = 0;
  bool _testFinished = false;
  int? _selectedIndex;
  String? _feedback;
  final Random _random = Random();
  String _playerName = 'Guest';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefsAndShowNameDialog();
    _prepareTest();
  }

  Future<void> _initPrefsAndShowNameDialog() async {
    _prefs = await SharedPreferences.getInstance();
    final savedName = _prefs.getString('playerName');
    
    setState(() {
      if (savedName != null) {
        _playerName = savedName;
      } else {
        // Show dialog to get player name if not saved
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPlayerNameDialog();
        });
      }
    });
  }

  Future<void> _showPlayerNameDialog() async {
    final TextEditingController nameController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t('Nhập tên của bạn', 'Enter your name')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: t('Nhập tên người chơi', 'Enter player name'),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _playerName = name;
                  });
                  _prefs.setString('playerName', name);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('Vui lòng nhập tên', 'Please enter a name'))),
                  );
                }
              },
              child: Text(t('Xác nhận', 'Confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTestResult() async {
    final result = TestResult(
      playerName: _playerName,
      totalScore: _score,
      audioScore: _audioScore,
      solfegeScore: _solfegeScore,
      keyScore: _keyScore,
      staffScore: _staffScore,
      timestamp: DateTime.now(),
      mode: _mode,
    );

    // Save to SharedPreferences
    final resultsJson = _prefs.getStringList('testResults') ?? [];
    resultsJson.add(jsonEncode(result.toJson()));
    await _prefs.setStringList('testResults', resultsJson);
    
    // Also save to progress tracker
    final progressTracker = ProgressTracker();
    await progressTracker.init();
    await progressTracker.recordTestResult(result);
  }

  void _prepareTest() {
    // set total based on mode
    setState(() {
      if (_mode == TestMode.mixed) {
        _totalQuestions = 100;
      } else {
        _totalQuestions = 20;
      }
      _questions = List.generate(_totalQuestions, (_) {
        // for mixed choose random mode per question
        final mode = _mode == TestMode.mixed
            ? TestMode.values[_random.nextInt(TestMode.values.length - 0)]
            : _mode;
        final noteIndex = _random.nextInt(notes.length);
        return Question(noteIndex, mode);
      });
      _currentQuestion = 0;
      _score = 0;
      _testFinished = false;
      _selectedIndex = null;
      _feedback = null;
        _audioScore = 0;
        _solfegeScore = 0;
        _keyScore = 0;
        _staffScore = 0;
    });
    // Auto-play audio for audio-based questions after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPlayIfAudio();
    });
  }

  void _autoPlayIfAudio() {
    if (_questions.isEmpty || _currentQuestion >= _questions.length) return;
    final q = _questions[_currentQuestion];
    if (q.mode == TestMode.audioToNote) {
      playNoteAssetByIndex(q.noteIndex);
    }
  }

  void _nextQuestion() {
    if (_currentQuestion >= _questions.length) {
      setState(() {
        _testFinished = true;
      });
      // Save result to leaderboard
      _saveTestResult();
      return;
    }
    setState(() {
      _selectedIndex = null;
      _feedback = null;
      _currentQuestion++;
    });
    // Auto-play for audio questions after advancing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPlayIfAudio();
    });
  }

  void _handleAnswer(int index) {
    if (_selectedIndex != null) return; // already answered
    setState(() {
      _selectedIndex = index;
      // play the tapped key sound for feedback
      playNoteAssetByIndex(index);
      final currentQ = _questions[_currentQuestion];
      final correctIndex = currentQ.noteIndex;
      if (index == correctIndex) {
        _score++;
        _feedback = 'correct';
        // Track score by category
        switch (currentQ.mode) {
          case TestMode.audioToNote:
            _audioScore++;
            break;
          case TestMode.solfegeToIntl:
            _solfegeScore++;
            break;
          case TestMode.intlToKey:
            _keyScore++;
            break;
          case TestMode.staffNotation:
            _staffScore++;
            break;
          case TestMode.mixed:
            // For mixed, just increment total
            break;
        }
      } else {
        _feedback = 'wrong';
      }
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _nextQuestion();
    });
  }

  void _restartTest() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _audioScore = 0;
      _solfegeScore = 0;
      _keyScore = 0;
      _testFinished = false;
    });
    _prepareTest();
  }

  Widget _buildTestFinishedScreen(bool isMobile, double horizontalPadding, double verticalPadding, double titleFontSize) {
    final accuracy = (_score / _totalQuestions * 100).toStringAsFixed(1);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('🎉 Hoàn thành kiểm tra!', '🎉 Test Complete!'),
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalPadding),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          t('Tổng điểm', 'Total Score'),
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          '$_score/$_totalQuestions',
                          style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        Text(
                          t('Độ chính xác: $accuracy%', 'Accuracy: $accuracy%'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: verticalPadding),
                if (_mode == TestMode.mixed || _audioScore > 0)
                  _buildScoreCard(t('🎵 Nghe nhạc', '🎵 Audio'), _audioScore, 'Audio'),
                if (_mode == TestMode.mixed || _solfegeScore > 0)
                  _buildScoreCard(t('🎼 Solfège', '🎼 Solfège'), _solfegeScore, 'Solfège'),
                if (_mode == TestMode.mixed || _keyScore > 0)
                  _buildScoreCard(t('⌨️ Phím', '⌨️ Keys'), _keyScore, 'Keys'),
                SizedBox(height: verticalPadding),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: _restartTest,
                          child: Text(t('Làm lại', 'Retry')),
                        ),
                    ),
                  ],
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    
    if (_testFinished) {
      return _buildTestFinishedScreen(isMobile, horizontalPadding, verticalPadding, titleFontSize);
    }
    // Safety check: ensure current question index is valid
    if (_currentQuestion >= _questions.length) {
      setState(() {
        _testFinished = true;
      });
      _saveTestResult();
      return _buildTestFinishedScreen(isMobile, horizontalPadding, verticalPadding, titleFontSize);
    }
    final currentQ = _questions[_currentQuestion];
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with mode selector
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t('Kiểm tra:', 'Test:')),
                        SizedBox(height: verticalPadding),
                        DropdownButton<TestMode>(
                          isExpanded: true,
                          value: _mode,
                          items: [
                            DropdownMenuItem(value: TestMode.mixed, child: Text(t('Trộn (100)', 'Mixed (100)'))),
                            DropdownMenuItem(value: TestMode.audioToNote, child: Text(t('Nghe -> Nốt', 'Audio -> Note'))),
                            DropdownMenuItem(value: TestMode.solfegeToIntl, child: Text(t('Solfège -> Quốc tế', 'Solfège -> Intl'))),
                            DropdownMenuItem(value: TestMode.intlToKey, child: Text(t('Quốc tế -> Phím', 'Intl -> Key'))),
                            DropdownMenuItem(value: TestMode.staffNotation, child: Text(t('Khuông nhạc -> Nốt', 'Staff -> Note'))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _mode = v;
                            });
                            _prepareTest();
                          },
                        ),
                        SizedBox(height: verticalPadding),
                        Center(
                          child: Text(t('Câu ${_currentQuestion + 1}/$_totalQuestions', 'Q ${_currentQuestion + 1}/$_totalQuestions'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t('Kiểm tra:', 'Test:')),
                        const SizedBox(width: 8),
                        DropdownButton<TestMode>(
                          value: _mode,
                          items: [
                            DropdownMenuItem(value: TestMode.mixed, child: Text(t('Trộn (100)', 'Mixed (100)'))),
                            DropdownMenuItem(value: TestMode.audioToNote, child: Text(t('Nghe -> Nốt', 'Audio -> Note'))),
                            DropdownMenuItem(value: TestMode.solfegeToIntl, child: Text(t('Solfège -> Quốc tế', 'Solfège -> Intl'))),
                            DropdownMenuItem(value: TestMode.intlToKey, child: Text(t('Quốc tế -> Phím', 'Intl -> Key'))),
                            DropdownMenuItem(value: TestMode.staffNotation, child: Text(t('Khuông nhạc -> Nốt', 'Staff -> Note'))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _mode = v;
                            });
                            _prepareTest();
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(t('Câu ${_currentQuestion + 1}/$_totalQuestions', 'Q ${_currentQuestion + 1}/$_totalQuestions')),
                      ],
                    ),
              SizedBox(height: verticalPadding),
              SizedBox(height: verticalPadding),
              // Question area varies by question mode
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: isMobile ? 200 : 250),
                child: _buildQuestionArea(currentQ, isMobile),
              ),
              SizedBox(height: verticalPadding),
              if (_feedback != null)
                Center(
                  child: Text(
                    _feedback == 'correct' ? t('Đúng!', 'Correct!') : t('Sai', 'Wrong'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _feedback == 'correct' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String title, int score, String category) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '$score',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionArea(Question q, bool isMobile) {
    final note = notes[q.noteIndex];
    switch (q.mode) {
      case TestMode.audioToNote:
        // Play button + multiple choice (international names)
        final options = _makeOptions(q.noteIndex);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      Text(t('Nghe và chọn nốt đúng', 'Listen and choose the correct note'), 
        style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 12 : 16),
            FilledButton.icon(
              onPressed: () => playNoteAssetByIndex(q.noteIndex),
              icon: const Icon(Icons.volume_up),
              label: Text(t('Nghe nốt', 'Play note')),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            Wrap(
              spacing: isMobile ? 8 : 12,
              runSpacing: isMobile ? 8 : 12,
              alignment: WrapAlignment.center,
              children: List.generate(options.length, (i) {
                final idx = options[i];
                return ElevatedButton(
                  onPressed: () => _handleAnswer(idx),
                  child: Text(notes[idx].international),
                );
              }),
            ),
          ],
        );
      case TestMode.solfegeToIntl:
        final options = _makeOptions(q.noteIndex);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      Text(t('Chọn tên quốc tế cho: ${note.solfege}', 'Choose international name for: ${note.solfege}'), 
        style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 16 : 24),
            Wrap(
              spacing: isMobile ? 8 : 12,
              runSpacing: isMobile ? 8 : 12,
              alignment: WrapAlignment.center,
              children: List.generate(options.length, (i) {
                final idx = options[i];
                return ElevatedButton(
                  onPressed: () => _handleAnswer(idx),
                  child: Text(notes[idx].international),
                );
              }),
            ),
          ],
        );
      case TestMode.intlToKey:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      Text(t('Chọn phím tương ứng với: ${note.international}', 'Choose the key corresponding to: ${note.international}'), 
        style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 16 : 24),
            PianoKeys(
              highlightedIndex: _selectedIndex,
              onKeyTapped: (i) => _handleAnswer(i),
            ),
          ],
        );
      case TestMode.staffNotation:
        final options = _makeOptions(q.noteIndex);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      Text(t('Đọc nốt từ khuông nhạc', 'Read the note from the staff'), 
        style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 12 : 16),
            if (isMobile)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35 * 0.7,
                child: MusicalStaff(
                  noteIndex: q.noteIndex,
                  initiallyShowNoteLabel: false,
                ),
              )
            else
              // Use a fixed, slightly smaller height for desktop/large screens
              // to keep the staff compact. Reduced to 70% (≈30% smaller).
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35 * 0.7,
                child: MusicalStaff(
                  noteIndex: q.noteIndex,
                  initiallyShowNoteLabel: false,
                ),
              ),
            SizedBox(height: isMobile ? 12 : 16),
      Text(t('Chọn tên nốt đúng', 'Choose the correct note name'), 
        style: TextStyle(fontSize: isMobile ? 14 : 16, fontStyle: FontStyle.italic)),
            SizedBox(height: isMobile ? 8 : 12),
            Wrap(
              spacing: isMobile ? 6 : 10,
              runSpacing: isMobile ? 6 : 10,
              alignment: WrapAlignment.center,
              children: List.generate(options.length, (i) {
                final idx = options[i];
                return ElevatedButton(
                  onPressed: () => _handleAnswer(idx),
                  child: Text(notes[idx].international),
                );
              }),
            ),
          ],
        );
      case TestMode.mixed:
        // Mixed delegates to its embedded mode (we set q.mode earlier)
        return _buildQuestionArea(Question(q.noteIndex, TestMode.values[_random.nextInt(TestMode.values.length)]), isMobile);
    }
  }

  List<int> _makeOptions(int correct) {
    // create 4 options including correct, shuffled
    final set = <int>{correct};
    while (set.length < 4) set.add(_random.nextInt(notes.length));
    final list = set.toList()..shuffle(_random);
    return list;
  }
}

/// Leaderboard page to show top players
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late SharedPreferences _prefs;
  List<TestResult> _allResults = [];
  List<LeaderboardEntry> _leaderboard = [];
  TestMode? _filterMode;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    _prefs = await SharedPreferences.getInstance();
    final resultsJson = _prefs.getStringList('testResults') ?? [];
    
    final results = <TestResult>[];
    for (final json in resultsJson) {
      try {
        results.add(TestResult.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (e) {
        print('Error parsing result: $e');
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // Create leaderboard entries
    final leaderboard = <LeaderboardEntry>[];
    for (int i = 0; i < results.length; i++) {
      final accuracy = (results[i].totalScore / 20 * 100); // Assuming 20 questions per non-mixed test
      leaderboard.add(LeaderboardEntry(
        rank: i + 1,
        result: results[i],
        accuracy: accuracy,
      ));
    }

    setState(() {
      _allResults = results;
      _leaderboard = leaderboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('🏆 Bảng Xếp Hạng', '🏆 Leaderboard'),
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: verticalPadding),
              // Filter buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(t('Tất cả', 'All')),
                      selected: _filterMode == null,
                      onSelected: (_) {
                        setState(() => _filterMode = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(t('🎵 Nghe', '🎵 Audio')),
                      selected: _filterMode == TestMode.audioToNote,
                      onSelected: (_) {
                        setState(() => _filterMode = TestMode.audioToNote);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(t('🎼 Solfège', '🎼 Solfège')),
                      selected: _filterMode == TestMode.solfegeToIntl,
                      onSelected: (_) {
                        setState(() => _filterMode = TestMode.solfegeToIntl);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(t('⌨️ Phím', '⌨️ Key')),
                      selected: _filterMode == TestMode.intlToKey,
                      onSelected: (_) {
                        setState(() => _filterMode = TestMode.intlToKey);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(t('🎼 Khuông nhạc', '🎼 Staff')),
                      selected: _filterMode == TestMode.staffNotation,
                      onSelected: (_) {
                        setState(() => _filterMode = TestMode.staffNotation);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalPadding),
              // Leaderboard list
              Expanded(
                child: _leaderboard.isEmpty
                    ? Center(
                        child: Text(
                          t('Chưa có kết quả nào', 'No results yet'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _leaderboard.length,
                        itemBuilder: (context, index) {
                          final entry = _leaderboard[index];
                          
                          // Apply filter
                          if (_filterMode != null && entry.result.mode != _filterMode) {
                            return const SizedBox.shrink();
                          }

                          final medal = entry.rank == 1
                              ? '🥇'
                              : entry.rank == 2
                                  ? '🥈'
                                  : entry.rank == 3
                                      ? '🥉'
                                      : '';
                          final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                          final formattedDate = dateFormat.format(entry.result.timestamp);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: entry.rank <= 3 ? 4 : 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$medal #${entry.rank} ${entry.result.playerName}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: entry.rank <= 3 ? Colors.blue : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        '${entry.result.totalScore} ${t('điểm', 'pts')}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        '${(entry.accuracy).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: entry.accuracy >= 80 ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (entry.result.mode != TestMode.mixed)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _getModeLabel(entry.result.mode),
                                        style: TextStyle(fontSize: 12, color: Colors.blue),
                                      ),
                                    ),
                                  if (entry.result.mode == TestMode.mixed)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text('🎵: ${entry.result.audioScore}  ', style: const TextStyle(fontSize: 11)),
                                          Text('🎼: ${entry.result.solfegeScore}  ', style: const TextStyle(fontSize: 11)),
                                          Text('⌨️: ${entry.result.keyScore}  ', style: const TextStyle(fontSize: 11)),
                                          Text('🎶: ${entry.result.staffScore}', style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getModeLabel(TestMode mode) {
    switch (mode) {
      case TestMode.audioToNote:
        return t('🎵 Nghe nhạc → Chọn nốt', '🎵 Audio → Note');
      case TestMode.solfegeToIntl:
        return t('🎼 Solfège → Quốc tế', '🎼 Solfège → Intl');
      case TestMode.intlToKey:
        return t('⌨️ Quốc tế → Phím piano', '⌨️ Intl → Piano Key');
      case TestMode.staffNotation:
        return t('🎶 Đọc khuông nhạc → Chọn nốt', '🎶 Read staff → Choose note');
      case TestMode.mixed:
        return t('Trộn lẫn', 'Mixed');
    }
  }
}

/// Progress tracking page showing daily improvements and motivational stats
class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late ProgressTracker _progressTracker;
  List<DailyProgress> _last7Days = [];
  List<CategoryProgress> _categoryProgress = [];
  List<TestResult> _allResults = [];
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _progressTracker = ProgressTracker();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    _prefs = await SharedPreferences.getInstance();
    await _progressTracker.init();
    
    // Load all test results
    final resultsJson = _prefs.getStringList('testResults') ?? [];
    final results = <TestResult>[];
    for (final json in resultsJson) {
      try {
        results.add(TestResult.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (e) {
        print('Error parsing result: $e');
      }
    }
    
    // Load last 7 days progress
    final last7 = await _progressTracker.getLast7DaysProgress();
    
    // Load category progress
    final categoryProgress = await _progressTracker.getCategoryProgress(results);
    
    setState(() {
      _allResults = results;
      _last7Days = last7;
      _categoryProgress = categoryProgress;
    });
  }

  String _getMotivationalMessage() {
    if (_allResults.isEmpty) {
      return t('🎯 Bắt đầu một bài test để theo dõi tiến bộ!', '🎯 Start a test to track your progress!');
    }
    
    // Calculate streak
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final json = _prefs.getString('daily_progress_$dateKey');
      if (json != null) {
        streak++;
      } else {
        break;
      }
    }
    
    final avgScore = _allResults.map((r) => r.totalScore).reduce((a, b) => a + b) ~/ _allResults.length;
    
    if (streak >= 7) {
      return t('🔥 Tuyệt vời! Bạn đã luyện tập $streak ngày liên tiếp!', '🔥 Nice! You have practiced $streak days in a row!');
    } else if (avgScore >= 18) {
      return t('⭐ Xuất sắc! Điểm trung bình của bạn là $avgScore/20!', '⭐ Excellent! Your average score is $avgScore/20!');
    } else if (_allResults.length >= 10) {
      return t('💪 Tốt lắm! Bạn đã hoàn thành ${_allResults.length} bài test!', '💪 Good job! You completed ${_allResults.length} tests!');
    } else if (_allResults.length >= 5) {
      return t('👏 Hay lắm! Tiếp tục cố gắng!', '👏 Nice work! Keep it up!');
    } else {
      return t('🌟 Bắt đầu tốt! Hãy tiếp tục!', '🌟 Good start! Keep going!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('📈 Tiến Bộ Của Bạn', '📈 Your Progress'),
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalPadding),
                
                // Motivational message
                Card(
                  color: Colors.blue.shade50,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _getMotivationalMessage(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: verticalPadding),
                
                // Summary stats
                if (_allResults.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          t('📊 Tổng bài test', '📊 Total tests'),
                          _allResults.length.toString(),
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          t('⭐ Điểm cao nhất', '⭐ Best score'),
                          _allResults.map((r) => r.totalScore).reduce(max).toString() + '/20',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                            t('📈 Điểm trung bình', '📈 Average score'),
                            (_allResults.map((r) => r.totalScore).reduce((a, b) => a + b) ~/ _allResults.length).toString() + '/20',
                            Colors.purple,
                          ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildStatCard(
                          t('📅 Ngày luyện', '📅 Practice days'),
                          _last7Days.length.toString(),
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalPadding),
                ],
                
                // Last 7 days progress
                Text(
                  t('📅 Tiến Bộ 7 Ngày Qua', '📅 Progress in the last 7 days'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                _last7Days.isEmpty
                    ? Center(
                        child: Text(
                          t('Chưa có dữ liệu', 'No data yet'),
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: _last7Days.asMap().entries.map((entry) {
                          final daily = entry.value;
                          final dayNames = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
                          final dayOfWeek = dayNames[daily.date.weekday % 7];
                          final formattedDate = '$dayOfWeek, ${daily.date.day.toString().padLeft(2, '0')}/${daily.date.month.toString().padLeft(2, '0')}';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${daily.testsCompleted}x',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: daily.bestScore / 20,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        daily.bestScore >= 18
                                            ? Colors.green
                                            : daily.bestScore >= 15
                                                ? Colors.blue
                                                : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${daily.bestScore}/20',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                SizedBox(height: verticalPadding),
                
                // Category performance
                Text(
                  '🎯 Hiệu Suất Theo Loại Bài',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                if (_categoryProgress.isEmpty)
                  Center(
                    child: Text(
                      'Chưa có dữ liệu',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Column(
                    children: _categoryProgress.map((category) {
                      final avgPercent = (category.averageScore / 20 * 100).toStringAsFixed(0);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      category.categoryName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${category.averageScore}/20 (${avgPercent}%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: category.averageScore / 20,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      int.parse(avgPercent) >= 90
                                          ? Colors.green
                                          : int.parse(avgPercent) >= 75
                                              ? Colors.blue
                                              : Colors.orange,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${category.totalTests} bài test • Điểm cao: ${category.bestScore}/20',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// About Page: displays app information, version, and team details.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Về ứng dụng', 'About')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App logo / icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.piano,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // App name
            Text(
              t('Piano Flashcards', 'Piano Flashcards'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Version
            Text(
              t('Phiên bản 1.0.0', 'Version 1.0.0'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Description section
            Text(
              t('Về ứng dụng', 'About this app'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            Text(
              t(
                'Piano Flashcards là một ứng dụng học nhạc tương tác được thiết kế để giúp người học ghi nhớ các nốt nhạc trên đàn piano. Với ba chế độ học khác nhau - Học, Match và Test - người dùng có thể nâng cao kỹ năng nhạc lý và nhận dạng nốt nhạc theo cách vui vẻ và hiệu quả.',
                'Piano Flashcards is an interactive music learning app designed to help learners memorize musical notes on a piano. With three different learning modes - Learn, Match, and Test - users can improve their music theory skills and note recognition abilities in a fun and effective way.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Features section
            Text(
              t('Các tính năng', 'Features'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            _buildFeatureItem(
              context,
              Icons.school,
              t('Chế độ Học', 'Learn Mode'),
              t('Học các nốt nhạc với thẻ ghi chú tương tác', 'Learn notes with interactive flashcards'),
            ),
            const SizedBox(height: 12),
            
            _buildFeatureItem(
              context,
              Icons.piano,
              t('Chế độ Match', 'Match Mode'),
              t('Kết hợp nốt nhạc với các phím đàn piano', 'Match notes with piano keys'),
            ),
            const SizedBox(height: 12),
            
            _buildFeatureItem(
              context,
              Icons.quiz,
              t('Chế độ Test', 'Test Mode'),
              t('Kiểm tra kiến thức và theo dõi tiến độ', 'Test knowledge and track progress'),
            ),
            const SizedBox(height: 24),
            
            // Team section
            Text(
              t('Đội ngũ phát triển', 'Development Team'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            Text(
              t(
                'Piano Flashcards được phát triển bởi một nhóm các nhà phát triển ứng dụng và giáo dục âm nhạc, với mục tiêu giúp người học toàn thế giới có thể tiếp cận giáo dục âm nhạc chất lượng cao.',
                'Piano Flashcards is developed by a team of app developers and music educators, dedicated to making quality music education accessible to learners worldwide.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact Page: displays contact information and contact form.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_emailController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(
            'Vui lòng điền vào tất cả các trường',
            'Please fill in all fields',
          )),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate sending email (in production, call backend API)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(
            'Cảm ơn! Chúng tôi sẽ phản hồi sớm.',
            'Thank you! We will respond soon.',
          )),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Liên hệ', 'Contact')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              t('Liên hệ với chúng tôi', 'Get in Touch'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),

            Text(
              t(
                'Có câu hỏi hoặc đề xuất? Hãy liên hệ với chúng tôi qua email hoặc form bên dưới.',
                'Have questions or suggestions? Contact us via email or the form below.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Contact info section
            Text(
              t('Thông tin liên hệ', 'Contact Information'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            _buildContactInfoItem(
              context,
              Icons.email,
              t('Email', 'Email'),
              'support@pianoflashcards.com',
            ),
            const SizedBox(height: 12),

            _buildContactInfoItem(
              context,
              Icons.public,
              t('Website', 'Website'),
              'www.pianoflashcards.com',
            ),
            const SizedBox(height: 24),

            // Social links
            Text(
              t('Theo dõi chúng tôi', 'Follow Us'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildSocialButton(context, Icons.facebook, 'Facebook'),
                const SizedBox(width: 12),
                _buildSocialButton(context, Icons.language, 'Twitter'),
                const SizedBox(width: 12),
                _buildSocialButton(context, Icons.link, 'Instagram'),
              ],
            ),
            const SizedBox(height: 32),

            // Contact form
            Text(
              t('Gửi tin nhắn', 'Send Message'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: t('Email của bạn', 'Your email'),
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: t('Chủ đề', 'Subject'),
                prefixIcon: const Icon(Icons.subject),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: t('Tin nhắn', 'Message'),
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t('Gửi', 'Send')),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(BuildContext context, IconData icon, String label) {
    return Tooltip(
      message: label,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('Chuyển hướng tới ', 'Redirecting to ') + label)),
            );
          },
        ),
      ),
    );
  }
}

/// Privacy Policy Page: displays privacy policy content.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Chính sách bảo mật', 'Privacy Policy')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _buildSection(
              context,
              t('Giới thiệu', 'Introduction'),
              t(
                'Piano Flashcards ("chúng tôi", "chúng tôi", hoặc "công ty") cam kết bảo vệ quyền riêng tư của bạn. Chính sách bảo mật này giải thích cách chúng tôi thu thập, sử dụng, tiết lộ và bảo safeguard thông tin của bạn.',
                'Piano Flashcards ("we", "us", or "company") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information.',
              ),
            ),

            // Data Collection
            _buildSection(
              context,
              t('Thu thập dữ liệu', 'Data Collection'),
              t(
                'Chúng tôi chỉ thu thập dữ liệu cần thiết để cải thiện ứng dụng của bạn, chẳng hạn như:\n• Tên người chơi\n• Điểm số và tiến độ học tập\n• Cài đặt ứng dụng (chẳng hạn như ngôn ngữ được chọn)',
                'We only collect data necessary to improve your app experience, such as:\n• Player name\n• Scores and learning progress\n• App settings (such as selected language)',
              ),
            ),

            // Data Usage
            _buildSection(
              context,
              t('Sử dụng dữ liệu', 'Data Usage'),
              t(
                'Thông tin chúng tôi thu thập được sử dụng để:\n• Cải thiện trải nghiệm người dùng\n• Theo dõi tiến độ học tập\n• Cá nhân hóa nội dung\n• Phân tích các xu hướng sử dụng',
                'The information we collect is used to:\n• Improve user experience\n• Track learning progress\n• Personalize content\n• Analyze usage trends',
              ),
            ),

            // Local Storage
            _buildSection(
              context,
              t('Lưu trữ cục bộ', 'Local Storage'),
              t(
                'Tất cả dữ liệu của bạn được lưu trữ cục bộ trên thiết bị của bạn. Chúng tôi không chia sẻ thông tin cá nhân của bạn với bất kỳ bên thứ ba nào mà không có sự đồng ý của bạn.',
                'All your data is stored locally on your device. We do not share your personal information with any third party without your consent.',
              ),
            ),

            // Security
            _buildSection(
              context,
              t('Bảo mật', 'Security'),
              t(
                'Chúng tôi sử dụng các biện pháp bảo mật tiêu chuẩn để bảo vệ thông tin của bạn khỏi truy cập, thay đổi, tiết lộ hoặc hủy diệt trái phép.',
                'We use standard security measures to protect your information from unauthorized access, alteration, disclosure, or destruction.',
              ),
            ),

            // Changes to Policy
            _buildSection(
              context,
              t('Thay đổi chính sách', 'Changes to Policy'),
              t(
                'Chúng tôi có thể cập nhật chính sách bảo mật này theo thời gian. Chúng tôi sẽ thông báo cho bạn về bất kỳ thay đổi nào bằng cách đăng chính sách mới trên trang này.',
                'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page.',
              ),
            ),

            // Contact for Privacy
            _buildSection(
              context,
              t('Liên hệ', 'Contact'),
              t(
                'Nếu bạn có bất kỳ câu hỏi nào về chính sách bảo mật này, vui lòng liên hệ với chúng tôi tại privacy@pianoflashcards.com',
                'If you have any questions about this Privacy Policy, please contact us at privacy@pianoflashcards.com',
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

  
    
  