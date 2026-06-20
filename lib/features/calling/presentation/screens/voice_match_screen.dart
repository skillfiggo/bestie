import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bestie/features/calling/data/repositories/voice_match_repository.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class VoiceMatchScreen extends ConsumerStatefulWidget {
  const VoiceMatchScreen({super.key});

  @override
  ConsumerState<VoiceMatchScreen> createState() => _VoiceMatchScreenState();
}

enum _MatchState { idle, searching, found, error }

class _VoiceMatchScreenState extends ConsumerState<VoiceMatchScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _foundController;
  late AnimationController _orbitController; // drives orbiting avatars

  late Animation<double> _radarAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _foundScale;
  late Animation<double> _foundOpacity;
  late Animation<double> _orbitAnimation;

  // ── State ─────────────────────────────────────────────────────
  _MatchState _state = _MatchState.idle;
  bool _hasPermission = false;
  bool _isNavigating = false;
  String? _errorText;
  int _elapsedSeconds = 0;
  String? _userGender;

  // Orbiting avatars
  List<Map<String, dynamic>> _orbitingProfiles = [];

  RealtimeChannel? _matchChannel;
  Timer? _timeoutTimer;
  Timer? _elapsedTimer;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkPermissions();
    _loadUserGender();
    _loadOrbitingProfiles();
  }

  void _initAnimations() {
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _radarAnimation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _radarController, curve: Curves.linear));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _foundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _foundScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _foundController, curve: Curves.elasticOut),
    );
    _foundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _foundController, curve: Curves.easeOut),
    );

    // Orbit — inner ring completes a full rotation every 8s
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _orbitAnimation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _orbitController, curve: Curves.linear));
  }

  Future<void> _loadOrbitingProfiles() async {
    try {
      final currentUserId = SupabaseService.client.auth.currentUser?.id;
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, name, avatar_url')
          .neq('id', currentUserId ?? '')
          .not('avatar_url', 'is', null)
          .neq('avatar_url', '')
          .order('created_at', ascending: false)
          .limit(7);

      if (mounted) {
        setState(() {
          _orbitingProfiles = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('🎤 Voice Match: Could not load orbiting profiles: \$e');
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (mounted) setState(() => _hasPermission = status.isGranted);
  }

  Future<void> _loadUserGender() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      setState(() => _userGender = profile.gender.toLowerCase());
    }
  }

  // ── Core matching flow ────────────────────────────────────────

  Future<void> _requestPermissionsAndStart() async {
    setState(() => _errorText = null);
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _errorText = 'Microphone permission is required for voice chats.');
      }
      return;
    }
    setState(() => _hasPermission = true);
    _startMatching();
  }

  Future<void> _startMatching() async {
    if (_state == _MatchState.searching) return;

    setState(() {
      _state = _MatchState.searching;
      _errorText = null;
      _elapsedSeconds = 0;
    });

    // 1. Start elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    try {
      final repo = ref.read(voiceMatchRepositoryProvider);

      // ────────────────────────────────────────────────────────────
      // RACE CONDITION FIX: Subscribe BEFORE calling joinQueue.
      // This ensures we never miss a 'matched' event that fires
      // between the RPC returning and the subscription being set up.
      // ────────────────────────────────────────────────────────────
      _matchChannel = repo.subscribeToMatch(
        onMatched: (result) {
          if (mounted && !_isNavigating && _state == _MatchState.searching) {
            _handleMatch(result);
          }
        },
      );

      // 2. Now join the queue
      final result = await repo.joinQueue(userGender: _userGender ?? 'any');

      if (!mounted) return;

      if (result.isMatched) {
        // Instantly matched (we're the initiator) — cancel the channel we set up
        _matchChannel?.unsubscribe();
        _matchChannel = null;
        await _handleMatch(result);
        return;
      }

      // 3. Waiting — start heartbeat and 60s timeout
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        repo.heartbeat();
      });

      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        if (mounted && _state == _MatchState.searching) {
          _cancelMatching();
          setState(() => _errorText = 'No one available right now — try again in a moment!');
        }
      });
    } catch (e) {
      debugPrint('🎤 Voice Match error: $e');
      if (mounted) {
        setState(() {
          _state = _MatchState.error;
          _errorText = 'Failed to connect. Please check your internet and try again.';
        });
        _stopTimers();
      }
    }
  }

  Future<void> _handleMatch(VoiceMatchResult result) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _stopTimers();

    // Show "Found!" celebration for 800ms before navigating
    setState(() => _state = _MatchState.found);
    _foundController.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    try {
      final matchedUserId = result.matchedUserId!;
      final channelId = result.channelId!;

      // Create/get DM chat so users can message each other after the call
      final chat = await ref.read(chatRepositoryProvider).createOrGetChat(matchedUserId);

      if (!mounted) return;

      // Leave queue before navigating (clean up DB row)
      await ref.read(voiceMatchRepositoryProvider).leaveQueue();

      if (!mounted) return;

      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelId: channelId,
            otherUserId: matchedUserId,
            isVideo: false,
            isInitiator: result.isInitiator,
            callHistoryId: null,
            isRandomMatch: true,
            dmChatId: chat.id,
          ),
        ),
      );

      // Reset when returning from call
      if (mounted) {
        _foundController.reset();
        setState(() {
          _state = _MatchState.idle;
          _isNavigating = false;
          _elapsedSeconds = 0;
        });
      }
    } catch (e) {
      debugPrint('🎤 Voice Match navigation error: $e');
      if (mounted) {
        _foundController.reset();
        setState(() {
          _state = _MatchState.idle;
          _isNavigating = false;
          _errorText = 'Failed to start call. Please try again.';
        });
      }
    }
  }

  Future<void> _cancelMatching() async {
    if (_state != _MatchState.searching) return;
    _stopTimers();
    await ref.read(voiceMatchRepositoryProvider).leaveQueue();
    if (mounted) {
      setState(() {
        _state = _MatchState.idle;
        _elapsedSeconds = 0;
      });
    }
  }

  void _stopTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _matchChannel?.unsubscribe();
    _matchChannel = null;
  }

  String _formatElapsed(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _foundController.dispose();
    _orbitController.dispose();
    _stopTimers();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0533), Color(0xFF0D1B4B), Color(0xFF0A2744)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _state == _MatchState.found
                      ? _buildFoundState()
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRadarAnimation(),
                              const SizedBox(height: 48),
                              _buildStatusSection(),
                              const SizedBox(height: 48),
                              _buildActionButton(),
                              if (_errorText != null) ...[
                                const SizedBox(height: 16),
                                _buildErrorBanner(),
                              ],
                            ],
                          ),
                        ),
                ),
                _buildBottomInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (_state == _MatchState.searching) await _cancelMatching();
              if (mounted) Navigator.pop(context);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              'Voice Match',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Elapsed timer pill (only shows when searching)
          AnimatedOpacity(
            opacity: _state == _MatchState.searching ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                _formatElapsed(_elapsedSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarAnimation() {
    final isSearching = _state == _MatchState.searching;
    // Full canvas size must fit outermost orbit ring (radius 190) + avatar diameter (44)
    const double canvasSize = 440;
    const double innerOrbitR = 140.0;
    const double outerOrbitR = 190.0;

    // Split profiles: inner ring gets 3, outer ring gets up to 4
    final inner = _orbitingProfiles.take(3).toList();
    final outer = _orbitingProfiles.skip(3).take(4).toList();

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings (only animate when searching)
          if (isSearching)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildRing(size: 260 * _pulseAnimation.value, opacity: 0.18, color: const Color(0xFFAB47BC)),
                    _buildRing(size: 200 * _pulseAnimation.value, opacity: 0.25, color: const Color(0xFF7E57C2)),
                    _buildRing(size: 150 * _pulseAnimation.value, opacity: 0.35, color: const Color(0xFF5C6BC0)),
                  ],
                );
              },
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                _buildRing(size: 200, opacity: 0.15, color: const Color(0xFF7E57C2)),
                _buildRing(size: 150, opacity: 0.20, color: const Color(0xFF5C6BC0)),
              ],
            ),

          // ── Orbiting avatar rings (only while searching) ────────────
          if (isSearching && _orbitingProfiles.isNotEmpty)
            AnimatedBuilder(
              animation: _orbitAnimation,
              builder: (context, _) {
                return SizedBox(
                  width: canvasSize,
                  height: canvasSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner ring — 3 avatars, clockwise
                      for (int i = 0; i < inner.length; i++)
                        _buildOrbitingAvatar(
                          profile: inner[i],
                          angle: _orbitAnimation.value + (2 * math.pi / inner.length) * i,
                          radius: innerOrbitR,
                          size: 44,
                          canvasSize: canvasSize,
                        ),
                      // Outer ring — up to 4 avatars, counter-clockwise (×0.65 slower)
                      for (int i = 0; i < outer.length; i++)
                        _buildOrbitingAvatar(
                          profile: outer[i],
                          angle: -_orbitAnimation.value * 0.65 + (2 * math.pi / outer.length) * i,
                          radius: outerOrbitR,
                          size: 38,
                          canvasSize: canvasSize,
                        ),
                    ],
                  ),
                );
              },
            ),

          // Base glow circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF9C27B0).withValues(alpha: 0.6),
                  const Color(0xFF3F51B5).withValues(alpha: 0.3),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB47BC).withValues(alpha: isSearching ? 0.5 : 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Radar sweep arm (only when searching)
          if (isSearching)
            AnimatedBuilder(
              animation: _radarAnimation,
              builder: (_, __) => CustomPaint(
                size: const Size(120, 120),
                painter: _RadarSweepPainter(angle: _radarAnimation.value),
              ),
            ),

          // Center icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(
              isSearching ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitingAvatar({
    required Map<String, dynamic> profile,
    required double angle,
    required double radius,
    required double size,
    required double canvasSize,
  }) {
    final double cx = canvasSize / 2;
    final double cy = canvasSize / 2;
    final double x = cx + radius * math.cos(angle) - size / 2;
    final double y = cy + radius * math.sin(angle) - size / 2;
    final String? avatarUrl = profile['avatar_url'] as String?;
    final String name = (profile['name'] as String? ?? '?');
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFAB47BC).withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAB47BC).withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(initial, size),
                )
              : _buildAvatarPlaceholder(initial, size),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String initial, double size) {
    return Container(
      color: const Color(0xFF4A148C),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRing({required double size, required double opacity, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }

  Widget _buildStatusSection() {
    final String title;
    final String subtitle;

    switch (_state) {
      case _MatchState.searching:
        title = _elapsedSeconds < 5
            ? 'Looking for someone...'
            : 'Matching you with someone special';
        subtitle = 'Connecting you with a random voice partner';
        break;
      case _MatchState.error:
        title = 'Something went wrong';
        subtitle = 'Please try again';
        break;
      default:
        title = 'Find a random voice chat partner';
        subtitle = 'Connect with someone new, right now';
    }

    return Column(
      children: [
        Text(
          'VOICE MATCH',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        if (_state == _MatchState.searching) ...[
          const SizedBox(height: 16),
          _buildSearchingDots(),
        ],
      ],
    );
  }

  Widget _buildSearchingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: Duration(milliseconds: 600 + i * 200),
          curve: Curves.easeInOut,
          builder: (_, value, __) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: value),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildFoundState() {
    return Center(
      child: ScaleTransition(
        scale: _foundScale,
        child: FadeTransition(
          opacity: _foundOpacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              const Text(
                'Match Found!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting you now...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_state == _MatchState.searching) {
      return GestureDetector(
        onTap: _cancelMatching,
        child: Container(
          width: 180,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
            color: Colors.red.withValues(alpha: 0.12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _hasPermission ? _startMatching : _requestPermissionsAndStart,
      child: Container(
        width: 200,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFAB47BC), Color(0xFF7E57C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAB47BC).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              _hasPermission ? 'Start Matching' : 'Allow Mic & Start',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange.shade300, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorText!,
              style: TextStyle(
                color: Colors.orange.shade200,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 6),
          Text(
            'Anonymous matching · Safe & monitored',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Radar Sweep Painter
// ─────────────────────────────────────────────
class _RadarSweepPainter extends CustomPainter {
  final double angle;
  _RadarSweepPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.9,
        endAngle: angle,
        colors: [
          Colors.transparent,
          const Color(0xFFAB47BC).withValues(alpha: 0.65),
        ],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle - 0.9,
      0.9,
      true,
      sweepPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.angle != angle;
}
