import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum ConnectionState { connected, offline, syncing }

/// Indicador de estado de conexión - Conectado / Sin señal / Sincronizando
/// Escucha dinámicamente el estado de internet del dispositivo (WiFi o Datos móviles).
class ConnectionStatus extends StatefulWidget {
  const ConnectionStatus({super.key});

  @override
  State<ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus> {
  ConnectionState _currentState = ConnectionState.connected;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _syncTimer;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    try {
      _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    } catch (e) {
      debugPrint("Connectivity stream not available: $e");
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint("Connectivity check not available: $e");
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Si la lista está vacía o contiene solo ConnectivityResult.none, está offline
    final isOffline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);

    if (mounted) {
      setState(() {
        if (isOffline) {
          _currentState = ConnectionState.offline;
          _wasOffline = true;
          _syncTimer?.cancel();
        } else {
          if (_wasOffline) {
            // Transición offline -> online: Sincronizando por 3 segundos
            _currentState = ConnectionState.syncing;
            _wasOffline = false;
            _syncTimer?.cancel();
            _syncTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _currentState = ConnectionState.connected;
                });
              }
            });
          } else {
            // Estaba online, se mantiene conectado
            if (_currentState != ConnectionState.syncing) {
              _currentState = ConnectionState.connected;
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = switch (_currentState) {
      ConnectionState.connected => (
        color: AppColors.primaryGreen,
        icon: LucideIcons.wifi,
        label: 'Conectado',
      ),
      ConnectionState.offline => (
        color: AppColors.alertOrange,
        icon: LucideIcons.wifiOff,
        label: 'Sin señal - Guardando',
      ),
      ConnectionState.syncing => (
        color: const Color(0xFF1E88E5),
        icon: LucideIcons.refreshCw,
        label: 'Sincronizando',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: AppTextStyles.caption.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
