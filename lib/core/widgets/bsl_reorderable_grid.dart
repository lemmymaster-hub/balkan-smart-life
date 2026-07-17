import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef BslReorderableItemBuilder<T extends Object> =
    Widget Function(
      BuildContext context,
      T item, {
      required bool isEditing,
      required bool isDragging,
      required bool isDropTarget,
    });

typedef BslReorderableFeedbackBuilder<T extends Object> =
    Widget Function(BuildContext context, T item);

class BslReorderableGrid<T extends Object> extends StatefulWidget {
  const BslReorderableGrid({
    super.key,
    required this.items,
    required this.itemId,
    required this.itemBuilder,
    required this.feedbackBuilder,
    required this.isEditing,
    required this.onEditingChanged,
    required this.onReorder,
    required this.onReorderEnd,
    required this.gridDelegate,
    this.padding = EdgeInsets.zero,
    this.longPressDelay = const Duration(milliseconds: 360),
  });

  final List<T> items;
  final String Function(T item) itemId;
  final BslReorderableItemBuilder<T> itemBuilder;
  final BslReorderableFeedbackBuilder<T> feedbackBuilder;
  final bool isEditing;
  final ValueChanged<bool> onEditingChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onReorderEnd;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry padding;
  final Duration longPressDelay;

  @override
  State<BslReorderableGrid<T>> createState() => _BslReorderableGridState<T>();
}

class _BslReorderableGridState<T extends Object>
    extends State<BslReorderableGrid<T>> {
  static const double _autoScrollEdge = 72;
  static const Duration _autoScrollInterval = Duration(milliseconds: 24);

  final GlobalKey _gridKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? _draggedItemId;
  String? _lastHoverTargetId;
  String? _scheduledReorderKey;
  Timer? _autoScrollTimer;
  double? _dragPointerY;

  @override
  void didUpdateWidget(covariant BslReorderableGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isEditing && !widget.isEditing && _draggedItemId == null) {
      _lastHoverTargetId = null;
      _scheduledReorderKey = null;
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.custom(
      key: _gridKey,
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: widget.gridDelegate,
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = widget.items[index];
          final id = widget.itemId(item);

          return KeyedSubtree(
            key: ValueKey<String>(id),
            child: _buildDropTarget(context, item, id),
          );
        },
        childCount: widget.items.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = widget.items.indexWhere(
            (item) => widget.itemId(item) == key.value,
          );
          return index < 0 ? null : index;
        },
      ),
    );
  }

  Widget _buildDropTarget(BuildContext context, T item, String id) {
    return DragTarget<T>(
      onWillAcceptWithDetails: (details) {
        final draggedId = widget.itemId(details.data);
        if (draggedId == id) return false;

        if (_lastHoverTargetId != id) {
          _lastHoverTargetId = id;
          _scheduleReorder(draggedId: draggedId, targetId: id);
        }

        return true;
      },
      onLeave: (_) {
        if (_lastHoverTargetId == id) {
          _lastHoverTargetId = null;
        }
      },
      onAcceptWithDetails: (_) {
        _lastHoverTargetId = null;
      },
      builder: (context, candidateData, rejectedData) {
        final isDragging = _draggedItemId == id;
        final isDropTarget = candidateData.isNotEmpty;

        return LayoutBuilder(
          builder: (context, constraints) {
            final child = widget.itemBuilder(
              context,
              item,
              isEditing: widget.isEditing,
              isDragging: isDragging,
              isDropTarget: isDropTarget,
            );

            final childWhenDragging = Opacity(
              opacity: 0.24,
              child: widget.itemBuilder(
                context,
                item,
                isEditing: true,
                isDragging: true,
                isDropTarget: false,
              ),
            );
            final feedback = Material(
              color: Colors.transparent,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Transform.scale(
                  scale: 1.04,
                  child: widget.feedbackBuilder(context, item),
                ),
              ),
            );

            if (widget.isEditing && _draggedItemId == null) {
              return Draggable<T>(
                data: item,
                feedback: feedback,
                childWhenDragging: childWhenDragging,
                maxSimultaneousDrags: 1,
                rootOverlay: true,
                onDragStarted: () => _startDrag(id),
                onDragUpdate: _updateAutoScroll,
                onDragEnd: (_) => _finishDrag(),
                child: child,
              );
            }

            return LongPressDraggable<T>(
              data: item,
              delay: widget.longPressDelay,
              feedback: feedback,
              childWhenDragging: childWhenDragging,
              maxSimultaneousDrags: 1,
              rootOverlay: true,
              onDragStarted: () => _startDrag(id),
              onDragUpdate: _updateAutoScroll,
              onDragEnd: (_) => _finishDrag(),
              child: child,
            );
          },
        );
      },
    );
  }

  void _startDrag(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggedItemId = id;
      _lastHoverTargetId = null;
      _scheduledReorderKey = null;
    });

    if (!widget.isEditing) {
      widget.onEditingChanged(true);
    }
  }

  void _finishDrag() {
    if (!mounted) return;

    setState(() {
      _draggedItemId = null;
      _lastHoverTargetId = null;
      _scheduledReorderKey = null;
    });
    _stopAutoScroll();
    HapticFeedback.selectionClick();
    widget.onReorderEnd();
  }

  void _updateAutoScroll(DragUpdateDetails details) {
    final renderObject = _gridKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    _dragPointerY = renderObject.globalToLocal(details.globalPosition).dy;
    final gridHeight = renderObject.size.height;
    _autoScrollTimer ??= Timer.periodic(
      _autoScrollInterval,
      (_) => _performAutoScroll(gridHeight),
    );
  }

  void _performAutoScroll(double gridHeight) {
    if (_draggedItemId == null ||
        _dragPointerY == null ||
        !_scrollController.hasClients) {
      return;
    }

    final pointerY = _dragPointerY!;
    var scrollDelta = 0.0;

    if (pointerY < _autoScrollEdge) {
      final intensity = (1 - pointerY / _autoScrollEdge)
          .clamp(0.0, 1.0)
          .toDouble();
      scrollDelta = -14 * intensity;
    } else if (pointerY > gridHeight - _autoScrollEdge) {
      final distanceFromBottom = gridHeight - pointerY;
      final intensity = (1 - distanceFromBottom / _autoScrollEdge)
          .clamp(0.0, 1.0)
          .toDouble();
      scrollDelta = 14 * intensity;
    }

    if (scrollDelta == 0) return;

    final position = _scrollController.position;
    final targetOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (targetOffset != position.pixels) {
      _scrollController.jumpTo(targetOffset);
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _dragPointerY = null;
  }

  void _scheduleReorder({required String draggedId, required String targetId}) {
    final reorderKey = '$draggedId->$targetId';
    if (_scheduledReorderKey == reorderKey) return;
    _scheduledReorderKey = reorderKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draggedItemId != draggedId) return;

      final oldIndex = widget.items.indexWhere(
        (item) => widget.itemId(item) == draggedId,
      );
      final newIndex = widget.items.indexWhere(
        (item) => widget.itemId(item) == targetId,
      );

      if (oldIndex >= 0 && newIndex >= 0 && oldIndex != newIndex) {
        HapticFeedback.selectionClick();
        widget.onReorder(oldIndex, newIndex);
      }

      _scheduledReorderKey = null;
    });
  }
}
