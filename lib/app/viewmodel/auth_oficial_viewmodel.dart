import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth_constants.dart';
import '../model/oficial_model.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/ficha_service.dart';
import '../services/visita_cartera_service.dart';
import '../services/preevaluacion_service.dart';
import '../services/solicitud_credito_service.dart';
import '../services/fcm_messaging_service.dart';
import '../workers/sincronizacion_nocturna_callback.dart';

enum AuthOficialState {
  initializing,
  unauthenticated,
  loading,
  authenticated,
  error,
}

class AuthOficialViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final FichaService _fichaService = FichaService();

  AuthOficialState _state = AuthOficialState.initializing;
  String _errorMessage = '';
  OficialModel? _oficial;
  Timer? _lockoutTimer;
  Duration? _lockoutRemaining;

  AuthOficialState get state => _state;
  String get errorMessage => _errorMessage;
  OficialModel? get oficial => _oficial;
  bool get isAuthenticated =>
      _state == AuthOficialState.authenticated && _oficial != null;
  Duration? get lockoutRemaining => _lockoutRemaining;
  bool get isLockedOut =>
      _lockoutRemaining != null && _lockoutRemaining!.inSeconds > 0;

  Future<void> initialize() async {
    _state = AuthOficialState.initializing;
    notifyListeners();

    try {
      await _refreshLockoutState();

      if (await _sessionService.isLockedOut()) {
        _state = AuthOficialState.unauthenticated;
        return;
      }

      final session = _authService.currentSession;
      if (session != null) {
        if (await _sessionService.isSessionExpiredByInactivity()) {
          await _clearSessionInternal();
          _errorMessage =
              'Tu sesión expiró por inactividad (${AuthConstants.sessionInactivityLimit.inHours} h). Inicia sesión nuevamente.';
          _state = AuthOficialState.unauthenticated;
        } else {
          final cached = await _sessionService.readProfileJson();
          _oficial = cached != null
              ? OficialModel.fromJsonString(cached)
              : await _authService
                  .restoreFromCurrentSession()
                  .timeout(const Duration(seconds: 12), onTimeout: () => null);

          if (_oficial != null) {
            await _sessionService.saveProfileJson(_oficial!.toJsonString());
            _state = AuthOficialState.authenticated;
            unawaited(_registrarFcm());
          } else {
            await _clearSessionInternal();
            _state = AuthOficialState.unauthenticated;
          }
        }
      } else {
        _state = AuthOficialState.unauthenticated;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Auth initialize error: $e');
      _state = AuthOficialState.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> login(String codigoEmpleado, String password) async {
    await _refreshLockoutState();
    if (isLockedOut) {
      _errorMessage = 'Cuenta bloqueada. Espera el tiempo indicado.';
      _state = AuthOficialState.error;
      notifyListeners();
      return;
    }

    _state = AuthOficialState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final user = await _authService
          .loginWithCodigoEmpleado(codigoEmpleado, password)
          .timeout(const Duration(seconds: 20));
      if (user != null) {
        await _sessionService.clearFailedAttempts();
        _oficial = user;
        await _sessionService.saveProfileJson(user.toJsonString());
        _state = AuthOficialState.authenticated;
        unawaited(_registrarFcm());
      } else {
        await _handleFailedLogin();
      }
    } on AuthRetryableFetchException catch (e) {
      _state = AuthOficialState.error;
      _errorMessage = _mensajeConexion(e);
    } on AuthApiException catch (e) {
      await _handleFailedLogin(message: _mapAuthError(e.message));
    } on AuthException catch (e) {
      await _handleFailedLogin(message: _mapAuthError(e.message));
    } on SocketException catch (e) {
      _state = AuthOficialState.error;
      _errorMessage = _mensajeConexion(e);
    } on TimeoutException catch (e) {
      _state = AuthOficialState.error;
      _errorMessage = _mensajeConexion(e);
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      _state = AuthOficialState.error;
      _errorMessage = _esErrorConexion(e)
          ? 'Error de conexión. Intenta nuevamente.'
          : 'No se pudo iniciar sesión. Intenta nuevamente.';
    }

    await _refreshLockoutState();
    notifyListeners();
  }

  Future<void> _handleFailedLogin({String? message}) async {
    await _sessionService.recordFailedAttempt();
    await _refreshLockoutState();

    if (isLockedOut) {
      _state = AuthOficialState.error;
      _errorMessage =
          'Demasiados intentos fallidos. Cuenta bloqueada por ${AuthConstants.lockoutDuration.inMinutes} minutos.';
    } else {
      final attempts = await _sessionService.getFailedAttempts();
      final restantes = AuthConstants.maxLoginAttempts - attempts;
      _state = AuthOficialState.error;
      _errorMessage = message ??
          'Código o contraseña incorrectos. Te quedan $restantes intento(s).';
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid') || lower.contains('credentials')) {
      return 'Código de empleado o contraseña incorrectos';
    }
    return message;
  }

  String _mensajeConexion(Object error) {
    if (kDebugMode) debugPrint('Error de conexión auth: $error');
    return 'Error de conexión. Verifica tu internet e intenta nuevamente.';
  }

  bool _esErrorConexion(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    if (error is AuthRetryableFetchException) return true;
    if (error is AuthUnknownException) {
      final original = error.originalError;
      return original is SocketException || original is TimeoutException;
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out');
  }

  Future<void> touchActivity() async {
    if (!isAuthenticated) return;
    await _sessionService.touchActivity();
  }

  Future<bool> checkInactivityExpiry() async {
    if (!isAuthenticated) return false;
    if (await _sessionService.isSessionExpiredByInactivity()) {
      _errorMessage =
          'Sesión cerrada por inactividad de ${AuthConstants.sessionInactivityLimit.inHours} horas.';
      await logout();
      return true;
    }
    return false;
  }

  /// Fichas + visitas + pre-evaluaciones pendientes de sincronizar.
  Future<int> pendingSyncCount() async {
    final fichas = await _fichaService.getOfflineCount();
    final visitas = await VisitaCarteraService().getOfflineCount();
    final preEval = await PreEvaluacionService().getOfflineCount();
    final solicitudes = await SolicitudCreditoService().contarPendientesEnvio();
    return fichas + visitas + preEval + solicitudes;
  }

  Future<void> logout() async {
    _oficial = null;
    _state = AuthOficialState.unauthenticated;
    notifyListeners();
    await _clearSessionInternal();
    notifyListeners();
  }

  Future<void> _clearSessionInternal() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('signOut error: $e');
    }
    try {
      await _sessionService.clearSession();
    } catch (e) {
      if (kDebugMode) debugPrint('clearSession error: $e');
    }
    if (!kIsWeb) {
      try {
        await _fichaService.clearOfflineCache();
        await VisitaCarteraService().clearOfflineCache();
        await PreEvaluacionService().clearOfflineCache();
        await SolicitudCreditoService().limpiarColaEnvio();
      } catch (e) {
        if (kDebugMode) debugPrint('clearOfflineCache error: $e');
      }
    }
    _oficial = null;
    _lockoutTimer?.cancel();
  }

  void resetLoginFormState() {
    if (_state == AuthOficialState.error) {
      _state = AuthOficialState.unauthenticated;
      _errorMessage = '';
      notifyListeners();
    }
  }

  Future<void> _registrarFcm() async {
    final o = _oficial;
    if (o == null) return;
    // Mismo id que usa solicitudescredito / vwperfilasesor
    final asesorid = o.asesorid.isNotEmpty ? o.asesorid : o.userid;
    if (asesorid.isEmpty) return;
    await FcmMessagingService.instance.inicializar(asesorid);
    try {
      await registrarSincronizacionNocturna();
    } catch (_) {}
  }

  Future<void> _refreshLockoutState() async {
    _lockoutRemaining = await _sessionService.remainingLockout();
    _lockoutTimer?.cancel();
    if (_lockoutRemaining != null && _lockoutRemaining!.inSeconds > 0) {
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        _lockoutRemaining = await _sessionService.remainingLockout();
        if (_lockoutRemaining == null || _lockoutRemaining!.inSeconds <= 0) {
          await _sessionService.clearFailedAttempts();
          _lockoutTimer?.cancel();
        }
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }
}
