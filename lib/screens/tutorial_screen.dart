import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game.dart';
import '../widgets/tile_widget.dart';
import '../board.dart';
import '../managers/responsive_wrapper.dart';
import '../widgets/click_button_widget.dart';
import '../sound_manager.dart';

// ── Step definitions ───────────────────────────────────────────────────────

enum _Step { welcome, tapReveal, readNumbers1, readNumbers2, flagMine1, flagMine2, complete }

class _StepConfig {
  final String title;
  final String message;
  final int targetRow;
  final int targetCol;
  final bool expectTap;
  final bool expectLongPress;
  final bool showNeighborhood;

  const _StepConfig({
    required this.title,
    required this.message,
    this.targetRow = -1,
    this.targetCol = -1,
    this.expectTap = false,
    this.expectLongPress = false,
    this.showNeighborhood = false,
  });
}

const _stepConfigs = <_Step, _StepConfig>{
  _Step.welcome: _StepConfig(
    title: 'Welcome to Mine Master!',
    message: 'Learn the rules in a few quick steps — then go beat the board!',
  ),
  _Step.tapReveal: _StepConfig(
    title: 'Tap to Reveal',
    message: "Tap the glowing tile to uncover what's beneath it.",
    targetRow: 0,
    targetCol: 0,
    expectTap: true,
  ),
  _Step.readNumbers1: _StepConfig(
    title: 'Read the Numbers',
    message:
        'This "1" means exactly one mine is hiding inside the blue border!',
    targetRow: 2,
    targetCol: 1,
    showNeighborhood: true,
  ),
  _Step.readNumbers2: _StepConfig(
    title: 'The "2" Works the Same Way',
    message:
        'This "2" means 2 mines are inside this border — both mines are hiding in here!',
    targetRow: 1,
    targetCol: 2,
    showNeighborhood: true,
  ),
  _Step.flagMine1: _StepConfig(
    title: 'Flag a Mine',
    message: 'Hold down the glowing tile to mark it as a mine.',
    targetRow: 2,
    targetCol: 2,
    expectLongPress: true,
  ),
  _Step.flagMine2: _StepConfig(
    title: 'Use the 2s!',
    message:
        'Each "2" touches 2 mines — and you\'ve already flagged one. That means the remaining hidden tile next to those "2"s must be the second mine. Press and hold it to flag it!',
    targetRow: 2,
    targetCol: 3,
    expectLongPress: true,
  ),
  _Step.complete: _StepConfig(
    title: "You're Ready!",
    message: "You've mastered the basics. Now go beat the real game!",
  ),
};

// ── TutorialScreen ─────────────────────────────────────────────────────────

class TutorialScreen extends StatefulWidget {
  /// When true (default, launched from home), completing the tutorial
  /// pushes straight to GameBoard. When false (launched from Settings),
  /// it just pops back.
  final bool launchGameOnComplete;

  const TutorialScreen({super.key, this.launchGameOnComplete = true});

  static const String _prefKey = 'tutorial_completed';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  late final Game _game;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  _Step _step = _Step.welcome;

  static const double _tileSize = 52.0;
  static const double _gap = 1.0;
  static const double _boardPx = 5 * _tileSize + 4 * _gap; // 264

  @override
  void initState() {
    super.initState();
    _game = _buildTutorialGame();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 5×5 board, bombs hard-coded at [0,4] and [4,4]
  Game _buildTutorialGame() {
    final game = Game(5, 5, 2, level: 0, score: 0);
    for (var row in game.board) {
      for (var tile in row) { tile.isBomb = false; }
    }
    game.board[2][2].isBomb = true;
    game.board[2][3].isBomb = true;
    game.calculateAdjacency();
    return game;
  }

  _StepConfig get _cfg => _stepConfigs[_step]!;

  void _advance() {
    setState(() {
      switch (_step) {
        case _Step.welcome:     _step = _Step.tapReveal; break;
        case _Step.tapReveal:    _step = _Step.readNumbers1; break;
        case _Step.readNumbers1: _step = _Step.readNumbers2; break;
        case _Step.readNumbers2: _step = _Step.flagMine1; break;
        case _Step.flagMine1:   _step = _Step.flagMine2; break;
        case _Step.flagMine2:   _step = _Step.complete; break;
        case _Step.complete:    _onComplete(); break;
      }
    });
  }

  Future<void> _onComplete() async {
    await TutorialScreen.markComplete();
    if (!mounted) return;
    if (widget.launchGameOnComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameBoard()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleTap(int r, int c) {
    if (!_cfg.expectTap) return;
    if (r != _cfg.targetRow || c != _cfg.targetCol) return;
    SoundManager.playReveal();
    SoundManager.vibrateReveal();
    setState(() => _game.reveal(r, c));
    _advance();
  }

  void _handleLongPress(int r, int c) {
    if (!_cfg.expectLongPress) return;
    if (r != _cfg.targetRow || c != _cfg.targetCol) return;
    final tile = _game.board[r][c];
    if (!tile.isRevealed && !tile.isFlagged) {
      SoundManager.playFlag();
      SoundManager.vibrateFlag();
      setState(() => tile.isFlagged = true);
    }
    _advance();
  }

  void _showSkipDialog() {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Skip tutorial?'),
          content: GestureDetector(
            onTap: () => setLocal(() => dontShowAgain = !dontShowAgain),
            child: Row(
              children: [
                Checkbox(
                  value: dontShowAgain,
                  activeColor: const Color(0xFF0B1E3D),
                  onChanged: (v) =>
                      setLocal(() => dontShowAgain = v ?? false),
                ),
                const Expanded(child: Text("Don't show again")),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Learning'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B1E3D),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (dontShowAgain) await TutorialScreen.markComplete();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text(
                'Skip',
                style: TextStyle(color: Color(0xFFFFDD00)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    final cfg = _cfg;
    return SizedBox(
      width: _boardPx,
      height: _boardPx,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int r = 0; r < 5; r++)
            for (int c = 0; c < 5; c++)
              Positioned(
                left: c * (_tileSize + _gap),
                top: r * (_tileSize + _gap),
                width: _tileSize,
                height: _tileSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TileWidget(
                    tile: _game.board[r][c],
                    onTap: () => _handleTap(r, c),
                    onLongPress: () => _handleLongPress(r, c),
                  ),
                ),
              ),
          // Blue 3×3 neighbourhood box — shows all tiles the number can "see"
          if (cfg.showNeighborhood && cfg.targetRow >= 0)
            Positioned(
              left: (cfg.targetCol - 1) * (_tileSize + _gap) - 5,
              top: (cfg.targetRow - 1) * (_tileSize + _gap) - 5,
              width: 3 * _tileSize + 2 * _gap + 10,
              height: 3 * _tileSize + 2 * _gap + 10,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.lightBlueAccent
                            .withValues(alpha: _pulseAnim.value),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.lightBlueAccent
                              .withValues(alpha: _pulseAnim.value * 0.35),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Pulsing highlight ring on target tile — IgnorePointer so the ring
          // doesn't block click/tap events from reaching the tile beneath it.
          if (cfg.targetRow >= 0)
            Positioned(
              left: cfg.targetCol * (_tileSize + _gap) - 4,
              top: cfg.targetRow * (_tileSize + _gap) - 4,
              width: _tileSize + 8,
              height: _tileSize + 8,
              child: IgnorePointer(
                child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFDD00)
                          .withValues(alpha: _pulseAnim.value),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFDD00)
                            .withValues(alpha: _pulseAnim.value * 0.5),
                        blurRadius: 14,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoodFrame({required Widget child}) {
    const r = 16.0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3316), Color(0xFF7A4A22), Color(0xFF4A2A12)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFF2F190A), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - 6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFCF4E4),
                Color(0xFFF3E4C8),
                Color(0xFFE6D1A8),
              ],
            ),
            borderRadius: BorderRadius.circular(r - 6),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    final cfg = _cfg;
    final bool showButton = !cfg.expectTap && !cfg.expectLongPress;
    final String? actionHint = cfg.expectTap
        ? 'Tap the highlighted tile'
        : cfg.expectLongPress
            ? 'Press and hold the highlighted tile'
            : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cfg.title,
            style: const TextStyle(
              color: Color(0xFF0B1E3D),
              fontFamily: 'Acsioma',
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            cfg.message,
            style: TextStyle(
              color: const Color(0xFF0B1E3D).withValues(alpha: 0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionHint != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app,
                    color: Color(0xFFFFA200), size: 18),
                const SizedBox(width: 6),
                Text(
                  actionHint,
                  style: const TextStyle(
                    color: Color(0xFFFFA200),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ClickButton(
                onPressed: () async {
                  SoundManager.playClick();
                  _advance();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  _step == _Step.complete ? "Let's Play!" : 'Next',
                  style: const TextStyle(
                    color: Color(0xFFFFDD00),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepDots() {
    // Show dots for all steps except complete
    final dotSteps = _Step.values
        .where((s) => s != _Step.complete)
        .toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dotSteps.map((s) {
        final active = s == _step;
        final past = s.index < _step.index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? const Color(0xFFFFDD00)
                : past
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background1.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Container(color: Colors.black.withValues(alpha: 0.38)),
          SafeArea(
            child: ResponsiveWrapper(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 8, 0),
                    child: Row(
                      children: [
                        const Text(
                          'HOW TO PLAY',
                          style: TextStyle(
                            color: Color(0xFFFFDD00),
                            fontFamily: 'Acsioma',
                            fontSize: 20,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _showSkipDialog,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  _buildStepDots(),
                  const SizedBox(height: 40),

                  // Board is fixed right below the dots — never moves.
                  Center(
                    child: _buildWoodFrame(child: _buildGrid()),
                  ),

                  const SizedBox(height: 12),

                  // Instruction card fills all remaining space below the board.
                  // Scrollable so long text never overflows on small screens.
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildInstructionCard(),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
