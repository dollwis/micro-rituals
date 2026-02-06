import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meditation.dart';
import '../theme/app_theme.dart';
import '../screens/audio_player_screen.dart';

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
  // ... (existing code variables)
  // We will work with a local list.
  List<Meditation> _cards = [];
  final List<Meditation> _history = []; // For Undo

  // For dragging
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  // Thresholds
  static const double _actionThreshold = 100.0; // Distance to trigger action

  @override
  void initState() {
    super.initState();
    _filterAndShuffleCards();
  }

  void _filterAndShuffleCards() {
    // Filter logic: Free user sees only free audio, premium user sees all.
    final available = widget.meditations.where((m) {
      if (widget.isSubscriber)
        return true; // Premium user sees all (logic per requirements)
      return !m.isPremium; // Free user sees only non-premium
    }).toList();

    // Shuffle for "random" discovery
    available.shuffle();

    setState(() {
      _cards = available;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;

    // Priorities: Top (Play) > Bottom (Listen Later) > Left/Right
    // But natural simple check:

    if (dy < -_actionThreshold) {
      // SWIPE TOP -> PLAY
      _playTopCard();
    } else if (dy > _actionThreshold) {
      // SWIPE BOTTOM -> LISTEN LATER
      _listenLaterTopCard();
    } else if (dx < -_actionThreshold) {
      // SWIPE LEFT -> NEXT (Skip)
      _skipTopCard();
    } else if (dx > _actionThreshold) {
      // SWIPE RIGHT -> UNDO (Previous)
      _undoLastAction();
    } else {
      // Return to center (spring back)
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  void _playTopCard() {
    if (_cards.isEmpty) return;
    final card = _cards.last;

    // Animate away perfectly up
    // In a real app we might animate, but for MVP just navigate
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AudioPlayerScreen(meditation: card)),
    );

    // Reset offset when coming back (or if they cancel nav)
    setState(() {
      _dragOffset = Offset.zero;
      // Should we remove it or keep it?
      // User might want to keep browsing. Let's keep it but reset position.
    });
  }

  void _listenLaterTopCard() {
    if (_cards.isEmpty) return;
    final card = _cards.last;

    widget.onListenLater(card);

    // Remove card after action
    setState(() {
      _history.add(card);
      _cards.removeLast();
      _dragOffset = Offset.zero;
    });
  }

  void _skipTopCard() {
    if (_cards.isEmpty) return;
    final card = _cards.last;

    setState(() {
      _history.add(card);
      _cards.removeLast();
      _dragOffset = Offset.zero;
    });
  }

  void _undoLastAction() {
    if (_history.isEmpty) {
      // Just reset if user tried to swipe right but no history
      setState(() {
        _dragOffset = Offset.zero;
      });
      return;
    }

    final previous = _history.removeLast();
    setState(() {
      _cards.add(previous); // Add back to top
      _dragOffset = Offset.zero;
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

    // We only need to render the top card (interactive) and maybe the one below it (for visuals)
    // List is structured so LAST element is ON TOP.
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
              // clipBehavior: Clip.none, // Not needed anymore
              children: [
                // Next Card (Behind)
                if (backCard != null)
                  Transform.scale(
                    scale: 0.95,
                    child: _buildCardUI(backCard, isFront: false),
                  ),

                // Front Card (Draggable)
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _dragOffset,
                    child: Transform.rotate(
                      angle:
                          _dragOffset.dx *
                          0.0005, // Subtle rotation while dragging
                      child: _buildCardUI(topCard, isFront: true),
                    ),
                  ),
                ),

                // Interaction Hints (Overlay based on drag)
                if (_isDragging) _buildDragOverlay(),
              ],
            ),
          ),

          const SizedBox(width: 16), // Spacing between card and button
          // Saved Collection Button (Now in Row)
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

  Widget _buildDragOverlay() {
    // Show icons based on direction
    IconData? icon;
    Color color = Colors.transparent;
    Alignment alignment = Alignment.center; // default

    double dx = _dragOffset.dx;
    double dy = _dragOffset.dy;

    if (dy < -50) {
      // Top
      icon = Icons.play_arrow_rounded;
      color = Colors.white;
      alignment = Alignment.topCenter;
    } else if (dy > 50) {
      // Bottom
      icon = Icons.bookmark_rounded;
      color = AppTheme.orange;
      alignment = Alignment.bottomCenter;
    } else if (dx < -50) {
      // Left
      icon = Icons.close_rounded;
      color = Colors.redAccent;
      alignment = Alignment.centerLeft;
    } else if (dx > 50) {
      // Right
      icon = Icons.replay_rounded; // Undo
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

  Widget _buildCardUI(Meditation data, {required bool isFront}) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.2,
            ), // Slightly darker shadow
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
            if (data.coverImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: data.coverImage,
                fit: BoxFit.cover,
                memCacheWidth: 600, // Optimization
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

            // 2. Gradient Overlay (Bottom)
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

            // 3. Info Chips
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Chip (Can be wider)
                  _buildInfoChip(
                    data.title,
                    isHighlight: true, // Distinct style for title
                  ),
                  const SizedBox(height: 8),
                  // Row for Category + Duration
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(data.category.toUpperCase()),
                      _buildInfoChip("${data.duration} min"),
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

  Widget _buildInfoChip(String label, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppTheme.getPrimary(context).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15), // Glassy look
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
