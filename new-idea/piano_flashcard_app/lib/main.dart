import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

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
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: 'Học nốt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.piano),
            label: 'Match phím',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined),
            label: 'Test',
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Học nốt nhạc',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Flashcard container
            Expanded(
              child: GestureDetector(
                onTap: _toggleAnswer,
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
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              currentNote.international,
                              key: ValueKey<bool>(_showAnswer),
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Instruction and control buttons
            Text(
              'Chạm vào thẻ để xem ${_showAnswer ? 'tên nốt' : 'tên solfège'}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
              ],
            ),
            const SizedBox(height: 16),
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
  static const _keyMap = {
    81: 0, // q
    87: 1, // w
    69: 2, // e
    82: 3, // r
    84: 4, // t
    89: 5, // y
    85: 6, // u
  };

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

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final code = event.logicalKey.keyId & 0xffff; // normalize
      final mapped = _keyMap[code];
      if (mapped != null) {
        widget.onKeyTapped(mapped);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final whiteKeyWidth = constraints.maxWidth / notes.length;
          return SizedBox(
            height: 120,
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
                        height: 120,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: isHighlighted ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(notes[index].international, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                          height: 80,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Match nốt với phím',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Display the note to match
            Text(
              'Hãy chọn phím tương ứng với nốt:',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${note.solfege}/${note.international}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            PianoKeys(
              highlightedIndex: _selectedIndex,
              onKeyTapped: _handleKeyTap,
            ),
            const SizedBox(height: 24),
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
    );
  }
}

/// Page that administers a short test to gauge the user's recall speed.
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  static const int _totalQuestions = 10;
  int _currentQuestion = 0;
  late int _currentNoteIndex;
  int _score = 0;
  bool _testFinished = false;
  int? _selectedIndex;
  String? _feedback;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentQuestion >= _totalQuestions) {
      setState(() {
        _testFinished = true;
      });
      return;
    }
    setState(() {
      // Choose a random note for each question.
      _currentNoteIndex = _random.nextInt(notes.length);
      _currentQuestion++;
      _selectedIndex = null;
      _feedback = null;
    });
  }

  void _handleAnswer(int index) {
    if (_selectedIndex != null) return; // already answered
    setState(() {
      _selectedIndex = index;
      if (index == _currentNoteIndex) {
        _score++;
        _feedback = 'Đúng!';
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
      _testFinished = false;
    });
    _nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (_testFinished) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hoàn thành kiểm tra!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Text(
                'Điểm của bạn: $_score/$_totalQuestions',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _restartTest,
                child: const Text('Làm lại'),
              ),
            ],
          ),
        ),
      );
    }

    final note = notes[_currentNoteIndex];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Câu $_currentQuestion/$_totalQuestions',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Nhận dạng nốt:',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                note.solfege + ' (${note.international})',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            PianoKeys(
              highlightedIndex: _selectedIndex,
              onKeyTapped: _handleAnswer,
            ),
            const SizedBox(height: 24),
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
    );
  }
}