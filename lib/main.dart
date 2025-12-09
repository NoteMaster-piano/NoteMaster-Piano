import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

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
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final cardFontSize = isMobile ? 48.0 : 64.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Học nốt nhạc',
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: verticalPadding),
              // Flashcard container
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: isMobile ? 200 : 250),
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
              // Instruction and control buttons
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _nextCard,
                            icon: const Icon(Icons.navigate_next),
                            label: const Text('Tiếp theo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _listenMode ? _stopListenMode : _startListenMode,
                            icon: const Icon(Icons.hearing),
                            label: Text(_listenMode ? 'Thoát' : 'Nghe & Chọn'),
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
              if (_listenMode) ...[
                SizedBox(height: verticalPadding),
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
            ],
          ),
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
  bool _testFinished = false;
  int? _selectedIndex;
  String? _feedback;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _prepareTest();
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
    _prepareTest();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 24.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    
    if (_testFinished) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hoàn thành kiểm tra!',
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalPadding),
                Text(
                  'Điểm của bạn: $_score/$_totalQuestions',
                  style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalPadding),
                FilledButton(
                  onPressed: _restartTest,
                  child: const Text('Làm lại'),
                ),
              ],
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

  