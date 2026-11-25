import 'dart:async';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class SearchLoadingGate extends StatefulWidget {
  const SearchLoadingGate({
    super.key,
    required this.loadingKey,
    required this.child,
    this.enabled = true,
    this.showOnInit = false,
    this.duration = const Duration(milliseconds: 400),
  });

  final Object? loadingKey;
  final Widget child;
  final bool enabled;
  final bool showOnInit;
  final Duration duration;

  @override
  State<SearchLoadingGate> createState() => _SearchLoadingGateState();
}

class _SearchLoadingGateState extends State<SearchLoadingGate> {
  static const _transitionDuration = Duration(milliseconds: 320);

  Timer? _timer;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled && widget.showOnInit && widget.loadingKey != null) _start();
  }

  @override
  void didUpdateWidget(covariant SearchLoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _timer?.cancel();
      _loading = false;
      return;
    }
    if (!oldWidget.enabled || widget.loadingKey != oldWidget.loadingKey) {
      if (widget.loadingKey != null) {
        _start();
      } else {
        _timer?.cancel();
        _loading = false;
      }
    }
  }

  void _start() {
    _timer?.cancel();
    _loading = true;
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading && widget.enabled;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: loading ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(ignoring: loading, child: widget.child),
        ),
        AnimatedSwitcher(
          duration: _transitionDuration,
          reverseDuration: _transitionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            if (child.key != const ValueKey('search-loading')) return const SizedBox.shrink();
            final curved = CurvedAnimation(parent: animation, curve: Curves.elasticOut, reverseCurve: Curves.elasticIn);
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
              child: ScaleTransition(scale: Tween<double>(begin: .82, end: 1).animate(curved), child: child),
            );
          },
          child: loading
              ? const Center(key: ValueKey('search-loading'), child: M3EContainedLoadingIndicator())
              : const SizedBox.shrink(key: ValueKey('search-loading-hidden')),
        ),
      ],
    );
  }
}
