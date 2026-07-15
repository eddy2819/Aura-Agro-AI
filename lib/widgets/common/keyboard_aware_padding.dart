import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ajusta únicamente el padding inferior cuando cambia el teclado.
///
/// A diferencia de consultar `MediaQuery.viewInsets` dentro de un formulario
/// grande, este widget limita las reconstrucciones de cada frame de la
/// animación del IME a una envoltura pequeña y conserva intacto su [child].
class KeyboardAwarePadding extends StatefulWidget {
  final EdgeInsets basePadding;
  final Widget child;

  const KeyboardAwarePadding({
    super.key,
    required this.basePadding,
    required this.child,
  });

  @override
  State<KeyboardAwarePadding> createState() => _KeyboardAwarePaddingState();
}

class _KeyboardAwarePaddingState extends State<KeyboardAwarePadding>
    with WidgetsBindingObserver {
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateInset();
  }

  @override
  void didChangeMetrics() => _updateInset();

  void _updateInset() {
    final ui.FlutterView? view =
        WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;

    final nextInset = view.viewInsets.bottom / view.devicePixelRatio;
    if ((nextInset - _keyboardInset).abs() < 0.5) return;

    if (mounted) {
      setState(() => _keyboardInset = nextInset);
    } else {
      _keyboardInset = nextInset;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.basePadding.copyWith(
        bottom: widget.basePadding.bottom + _keyboardInset,
      ),
      child: widget.child,
    );
  }
}

/// Retira un efecto costoso tan pronto empieza a aparecer el teclado.
/// Solo reconstruye cuando cambia entre visible/oculto, no en cada frame.
class HideWhenKeyboardVisible extends StatefulWidget {
  final Widget child;

  const HideWhenKeyboardVisible({super.key, required this.child});

  @override
  State<HideWhenKeyboardVisible> createState() =>
      _HideWhenKeyboardVisibleState();
}

class _HideWhenKeyboardVisibleState extends State<HideWhenKeyboardVisible>
    with WidgetsBindingObserver {
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readVisibility(notify: false);
  }

  @override
  void didChangeMetrics() => _readVisibility();

  void _readVisibility({bool notify = true}) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final isVisible = view != null && view.viewInsets.bottom > 0;
    if (isVisible == _isKeyboardVisible) return;

    if (notify && mounted) {
      setState(() => _isKeyboardVisible = isVisible);
    } else {
      _isKeyboardVisible = isVisible;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !_isKeyboardVisible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: widget.child,
    );
  }
}
