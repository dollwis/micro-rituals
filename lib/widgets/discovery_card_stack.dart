import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'ritual_cover_image.dart';
import '../models/meditation.dart';
import '../theme/app_theme.dart';
import '../screens/audio_player_screen.dart';

enum SwipeDirection { left, right, top, bottom }

class DiscoveryCardStack extends StatefulWidget {
  final List<Meditation> meditations;
  final bool isSubscriber;
  final Function(Meditation) onListenLater;
  final VoidCallback onViewCollection;

  const DiscoveryCardStack({
    super.key,
    required this.meditations,
    required this.isSubscriber,
    required this.onListenLater,
    required this.onViewCollection,
  });

  @override
  State<DiscoveryCardStack> createState() => _DiscoveryCardStackState();
}

class _DiscoveryCardStackState extends State<DiscoveryCardStack> {
  List<Meditation> _cards = [];
  final List<Meditation> _history = []; // For Undo

  @override
  void initState() {
    super.initState();
    _filterAndShuffleCards();
  }

  void _filterAndShuffleCards() {
    // Filter logic: Free user sees only free audio, premium user sees all.
    final available = widget.meditations.where((m) {
      if (widget.isSubscriber) {
        return true; // Premium user sees all
      }
      return !m.isPremium; // Free user sees only non-premium
    }).toList();

    // Shuffle for "random" discovery
    available.shuffle();

    setState(() {
      _cards = available;
    });
  }

  void _handleSwipe(SwipeDirection direction) {
    if (_cards.isEmpty) return;
    final card = _cards.last;

    switch (direction) {
      case SwipeDirection.top:
        // Play
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerScreen(meditation: card),
          ),
        );
        // We keep the card for now as user might return.
        // Or should we reshuffle it?
        // Let's keep it as is.
        break;

      case SwipeDirection.bottom:
        // Listen Later
        widget.onListenLater(card);
        setState(() {
          _history.add(card);
          _cards.removeLast();
        });
        break;

      case SwipeDirection.left:
        // Skip
        setState(() {
          _history.add(card);
          _cards.removeLast();
        });
        break;

      case SwipeDirection.right:
        // Undo (Special case handled by undo button or gesture?)
        // The requirements say Swipe Right -> Undo previous action.
        // Logic: Swiping RIGHT on the CURRENT card usually means "Keeping it" or "Back".
        // BUT the user prompt code implies: "SWIPE RIGHT -> UNDO (Previous)"
        // Typically Undo restores a PREVIOUSLY removed card.
        // So swiping the CURRENT card right to UNDO means... what?
        // Looking at previous logic:
        // _undoLastAction() -> _history.removeLast() -> _cards.add(previous)
        // Check previous code:
        // } else if (dx > _actionThreshold) {
        //   // SWIPE RIGHT -> UNDO (Previous)
        //   _undoLastAction();
        // }
        // Wait, if I swipe the *current* card right, I trigger undo of the *previous* action?
        // Yes, that's what the code did.
        _undoLastAction();
        break;
    }
  }

  void _undoLastAction() {
    if (_history.isEmpty) return;

    final previous = _history.removeLast();
    setState(() {
      _cards.add(previous); // Add back to top
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Container(
        height: 480,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_clear,
              size: 48,
              color: AppTheme.getMutedColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              "No more cards!",
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
            TextButton(
              onPressed: _filterAndShuffleCards,
              child: const Text("Shuffle Again"),
            ),
          ],
        ),
      );
    }

    final topIndex = _cards.length - 1;
    final topCard = _cards[topIndex];
    final backCard = (topIndex > 0) ? _cards[topIndex - 1] : null;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next Card (Behind) - Static
                if (backCard != null)
                  Transform.scale(
                    scale: 0.95,
                    child: DiscoveryCard(meditation: backCard, isFront: false),
                  ),

                // Front Card (Draggable) - Handles its own drag state
                // Key is important to rebuild state when topCard changes
                _DraggableCard(
                  key: ValueKey(topCard.id),
                  meditation: topCard,
                  onSwipe: _handleSwipe,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),
          // Saved Collection Button
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: widget.onViewCollection,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bookmark_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableCard extends StatefulWidget {
  final Meditation meditation;
  final Function(SwipeDirection) onSwipe;

  const _DraggableCard({
    required Key key,
    required this.meditation,
    required this.onSwipe,
  }) : super(key: key);

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> {
  final ValueNotifier<Offset> _dragNotifier = ValueNotifier(Offset.zero);
  bool _isDragging = false;
  static const double _actionThreshold = 100.0;

  @override
  void dispose() {
    _dragNotifier.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragNotifier.value += details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final offset = _dragNotifier.value;
    final dx = offset.dx;
    final dy = offset.dy;

    if (dy < -_actionThreshold) {
      widget.onSwipe(SwipeDirection.top);
    } else if (dy > _actionThreshold) {
      widget.onSwipe(SwipeDirection.bottom);
    } else if (dx < -_actionThreshold) {
      widget.onSwipe(SwipeDirection.left);
    } else if (dx > _actionThreshold) {
      widget.onSwipe(SwipeDirection.right);
      _resetPosition();
    } else {
      _resetPosition();
    }
  }

  void _resetPosition() {
    _dragNotifier.value = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _dragNotifier,
      child: DiscoveryCard(meditation: widget.meditation, isFront: true),
      builder: (context, offset, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: offset.dx * 0.0005,
                  child: child!,
                ),
              ),
            ),
            if (_isDragging) _buildDragOverlay(offset),
          ],
        );
      },
    );
  }

  Widget _buildDragOverlay(Offset offset) {
    IconData? icon;
    Color color = Colors.transparent;
    Alignment alignment = Alignment.center;

    final dx = offset.dx;
    final dy = offset.dy;

    if (dy < -50) {
      icon = Icons.play_arrow_rounded;
      color = Colors.white;
      alignment = Alignment.topCenter;
    } else if (dy > 50) {
      icon = Icons.bookmark_rounded;
      color = AppTheme.orange;
      alignment = Alignment.bottomCenter;
    } else if (dx < -50) {
      icon = Icons.close_rounded;
      color = Colors.redAccent;
      alignment = Alignment.centerLeft;
    } else if (dx > 50) {
      icon = Icons.replay_rounded;
      color = Colors.yellow[700]!;
      alignment = Alignment.centerRight;
    }

    if (icon == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class DiscoveryCard extends StatefulWidget {
  final Meditation meditation;
  final bool isFront;

  const DiscoveryCard({
    super.key,
    required this.meditation,
    required this.isFront,
  });

  @override
  State<DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<DiscoveryCard> {
  late final AudioPlayer _previewPlayer;
  bool _isPlaying = false;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _previewPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _stopPreview();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_isPlaying) {
      _stopPreview();
    } else {
      await _startPreview();
    }
  }

  Future<void> _startPreview() async {
    try {
      if (widget.meditation.audioUrl.isEmpty) return;

      await _previewPlayer.setUrl(widget.meditation.audioUrl);
      await _previewPlayer.play();

      if (mounted) {
        setState(() => _isPlaying = true);
      }

      // Auto-stop after 10 seconds
      _stopTimer = Timer(const Duration(seconds: 10), _stopPreview);
    } catch (e) {
      debugPrint('Preview error: $e');
      _stopPreview();
    }
  }

  void _stopPreview() {
    _stopTimer?.cancel();
    _previewPlayer.stop();
    _previewPlayer.seek(Duration.zero);
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Cover Image
            if (widget.meditation.coverImage.isNotEmpty)
              RitualCoverImage(
                imageUrl: widget.meditation.coverImage,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                memCacheHeight: 800,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                  child: Icon(
                    Icons.spa,
                    color: AppTheme.getMutedColor(context),
                  ),
                ),
              )
            else
              Container(
                color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                child: Icon(
                  Icons.spa,
                  size: 60,
                  color: AppTheme.getPrimary(context).withValues(alpha: 0.5),
                ),
              ),

            // 2. Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Play/Pause Button (top-right)
            if (widget.isFront)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // 4. Info Chips
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoChip(
                    context,
                    widget.meditation.title,
                    isHighlight: true,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        context,
                        widget.meditation.category.toUpperCase(),
                      ),
                      _buildInfoChip(
                        context,
                        widget.meditation.formattedDuration,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppTheme.getPrimary(context).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: isHighlight ? 0.3 : 0.1),
        ),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHighlight ? 14 : 12,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
