import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
void main() {
  runApp(const NoteFlashcardApp());
}

/// Root widget of the flashcard application.
class NoteFlashcardApp extends StatelessWidget {
  const NoteFlashcardApp({super.key});

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
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/leaderboard') {
          return MaterialPageRoute(
            builder: (context) => const LeaderboardPage(),
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
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
        label: const Text('Bảng xếp hạng'),
        icon: const Icon(Icons.emoji_events),
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.school_outlined),
                  label: 'Học nốt',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.piano),
                  label: 'Match',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.quiz_outlined),
                  label: 'Test',
                ),
              ],
            )
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  label: 'Học nốt nhạc',
                ),
                NavigationDestination(
                  icon: Icon(Icons.piano),
                  label: 'Match nốt với phím',
                ),
                NavigationDestination(
                  icon: Icon(Icons.quiz_outlined),
                  label: 'Kiểm tra',
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
  final DateTime timestamp;
  final TestMode mode;

  TestResult({
    required this.playerName,
    required this.totalScore,
    required this.audioScore,
    required this.solfegeScore,
    required this.keyScore,
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
            Text(
              'Học nốt nhạc',
              style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: verticalPadding),
            // Flashcard container - Fixed height based on screen
            SizedBox(
              height: cardHeight,
              child: GestureDetector(
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
              'Chạm vào thẻ để xem ${_showAnswer ? 'tên nốt' : 'tên solfège'}',
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
                          label: Text(_showAnswer ? 'Ẩn' : 'Hiện'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _nextCard,
                          icon: const Icon(Icons.navigate_next),
                          label: const Text('Tiếp'),
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
                          label: Text(_isPlaying ? 'Phát...' : 'Nghe'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _listenMode ? _stopListenMode : _startListenMode,
                          icon: const Icon(Icons.hearing),
                          label: Text(_listenMode ? 'Thoát' : 'Chọn'),
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
                    label: Text(_showAnswer ? 'Ẩn' : 'Hiện'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _nextCard,
                    icon: const Icon(Icons.navigate_next),
                    label: const Text('Tiếp theo'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isPlaying ? null : _playCurrentNote,
                    icon: const Icon(Icons.volume_up),
                    label: Text(_isPlaying ? 'Đang phát...' : 'Nghe'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _listenMode ? _stopListenMode : _startListenMode,
                    icon: const Icon(Icons.hearing),
                    label: Text(_listenMode ? 'Thoát nghe' : 'Nghe & Chọn'),
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
                          label: const Text('Nghe nốt'),
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
                                  _learnFeedback = 'Đúng!';
                                } else {
                                  _learnFeedback = 'Sai';
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
                            child: Text(_learnFeedback!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _learnFeedback == 'Đúng!' ? Colors.green : Colors.red)),
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
        _feedback = 'Chính xác!';
      } else {
        _feedback = 'Sai rồi :(';    
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
                'Match nốt với phím',
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: verticalPadding),
              // Display the note to match
              Text(
                'Hãy chọn phím tương ứng với nốt:',
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
                    _feedback!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _feedback == 'Chính xác!'
                          ? Colors.green
                          : Colors.red,
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

enum TestMode { mixed, audioToNote, solfegeToIntl, intlToKey }

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
  bool _testFinished = false;
  int? _selectedIndex;
  String? _feedback;
  final Random _random = Random();
  String _playerName = 'Guest';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _prepareTest();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final savedName = _prefs.getString('playerName') ?? 'Guest';
    setState(() {
      _playerName = savedName;
    });
  }

  Future<void> _saveTestResult() async {
    final result = TestResult(
      playerName: _playerName,
      totalScore: _score,
      audioScore: _audioScore,
      solfegeScore: _solfegeScore,
      keyScore: _keyScore,
      timestamp: DateTime.now(),
      mode: _mode,
    );

    // Save to SharedPreferences
    final resultsJson = _prefs.getStringList('testResults') ?? [];
    resultsJson.add(jsonEncode(result.toJson()));
    await _prefs.setStringList('testResults', resultsJson);
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
        _feedback = 'Đúng!';
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
          case TestMode.mixed:
            // For mixed, just increment total
            break;
        }
      } else {
        _feedback = 'Sai';
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    
    if (_testFinished) {
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
                    '🎉 Hoàn thành kiểm tra!',
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
                            'Tổng điểm',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            '$_score/$_totalQuestions',
                            style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          Text(
                            'Độ chính xác: $accuracy%',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: verticalPadding),
                  if (_mode == TestMode.mixed || _audioScore > 0)
                    _buildScoreCard('🎵 Nghe nhạc', _audioScore, 'Audio'),
                  if (_mode == TestMode.mixed || _solfegeScore > 0)
                    _buildScoreCard('🎼 Solfège', _solfegeScore, 'Solfège'),
                  if (_mode == TestMode.mixed || _keyScore > 0)
                    _buildScoreCard('⌨️ Phím', _keyScore, 'Keys'),
                  SizedBox(height: verticalPadding),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _restartTest,
                          child: const Text('Làm lại'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            // Navigate to leaderboard using named route
                            Navigator.of(context).pushNamed('/leaderboard');
                          },
                          child: const Text('Xem Leaderboard'),
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
    final currentQ = _questions.isNotEmpty ? _questions[_currentQuestion] : Question(_random.nextInt(notes.length), TestMode.audioToNote);
    
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
                        const Text('Kiểm tra:'),
                        SizedBox(height: verticalPadding),
                        DropdownButton<TestMode>(
                          isExpanded: true,
                          value: _mode,
                          items: const [
                            DropdownMenuItem(value: TestMode.mixed, child: Text('Trộn (100)')),
                            DropdownMenuItem(value: TestMode.audioToNote, child: Text('Nghe -> Nốt')),
                            DropdownMenuItem(value: TestMode.solfegeToIntl, child: Text('Solfège -> Quốc tế')),
                            DropdownMenuItem(value: TestMode.intlToKey, child: Text('Quốc tế -> Phím')),
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
                          child: Text('Câu ${_currentQuestion + 1}/$_totalQuestions',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Kiểm tra:'),
                        const SizedBox(width: 8),
                        DropdownButton<TestMode>(
                          value: _mode,
                          items: const [
                            DropdownMenuItem(value: TestMode.mixed, child: Text('Trộn (100)')),
                            DropdownMenuItem(value: TestMode.audioToNote, child: Text('Nghe -> Nốt')),
                            DropdownMenuItem(value: TestMode.solfegeToIntl, child: Text('Solfège -> Quốc tế')),
                            DropdownMenuItem(value: TestMode.intlToKey, child: Text('Quốc tế -> Phím')),
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
                        Text('Câu ${_currentQuestion + 1}/$_totalQuestions'),
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
                    _feedback!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _feedback == 'Đúng!' ? Colors.green : Colors.red,
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
            Text('Nghe và chọn nốt đúng', 
                style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 12 : 16),
            FilledButton.icon(
              onPressed: () => playNoteAssetByIndex(q.noteIndex),
              icon: const Icon(Icons.volume_up),
              label: const Text('Nghe nốt'),
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
            Text('Chọn tên quốc tế cho: ${note.solfege}', 
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
            Text('Chọn phím tương ứng với: ${note.international}', 
                style: TextStyle(fontSize: isMobile ? 18 : 20)),
            SizedBox(height: isMobile ? 16 : 24),
            PianoKeys(
              highlightedIndex: _selectedIndex,
              onKeyTapped: (i) => _handleAnswer(i),
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
                  '🏆 Bảng Xếp Hạng',
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: verticalPadding),
            // Filter buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _filterMode == null,
                    onSelected: (_) {
                      setState(() => _filterMode = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('🎵 Nghe'),
                    selected: _filterMode == TestMode.audioToNote,
                    onSelected: (_) {
                      setState(() => _filterMode = TestMode.audioToNote);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('🎼 Solfège'),
                    selected: _filterMode == TestMode.solfegeToIntl,
                    onSelected: (_) {
                      setState(() => _filterMode = TestMode.solfegeToIntl);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('⌨️ Phím'),
                    selected: _filterMode == TestMode.intlToKey,
                    onSelected: (_) {
                      setState(() => _filterMode = TestMode.intlToKey);
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
                        'Chưa có kết quả nào',
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
                                      '${entry.result.totalScore} điểm',
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
                                        Text('⌨️: ${entry.result.keyScore}', style: const TextStyle(fontSize: 11)),
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
    );
  }

  String _getModeLabel(TestMode mode) {
    switch (mode) {
      case TestMode.audioToNote:
        return '🎵 Nghe nhạc → Chọn nốt';
      case TestMode.solfegeToIntl:
        return '🎼 Solfège → Quốc tế';
      case TestMode.intlToKey:
        return '⌨️ Quốc tế → Phím piano';
      case TestMode.mixed:
        return 'Trộn lẫn';
    }
  }
}

  
  