import 'package:flutter/material.dart';
import '../model/solicitud_credito_data.dart';
import '../services/solicitud_credito_service.dart';

class SolicitudCreditoViewModel extends ChangeNotifier {
  final SolicitudCreditoService _service = SolicitudCreditoService();

  SolicitudCreditoData? _data;
  int _paso = 0;
  bool _guardando = false;
  bool _enviando = false;
  String? _mensaje;
  int _pendientesEnvio = 0;
  List<SolicitudBorradorResumen> _borradores = [];

  SolicitudCreditoData? get data => _data;
  int get paso => _paso;
  bool get guardando => _guardando;
  bool get enviando => _enviando;
  String? get mensaje => _mensaje;
  int get pendientesEnvio => _pendientesEnvio;
  List<SolicitudBorradorResumen> get borradores => _borradores;

  void iniciar({required String asesorid, SolicitudCreditoData? existente}) {
    _data = existente != null
        ? SolicitudCreditoData.fromJson(existente.toJson())
        : SolicitudCreditoData(asesorid: asesorid);
    _paso = _data!.pasoActual.clamp(0, 3);
    _mensaje = null;
    notifyListeners();
  }

  void actualizar(SolicitudCreditoData data) {
    _data = data;
    notifyListeners();
  }

  void irAPaso(int paso) {
    _paso = paso.clamp(0, 3);
    if (_data != null) _data!.pasoActual = _paso;
    notifyListeners();
  }

  String? validarPaso(int paso) {
    final d = _data;
    if (d == null) return 'Sin datos';

    switch (paso) {
      case 0:
        if (!d.sePudoVisitar) return null; // No need to validate if not visited (UI will block)
        if (d.nombreNegocio.trim().isEmpty) return 'Nombre del negocio requerido';
        if (d.direccionNegocio.trim().isEmpty) return 'Dirección requerida';
        if (d.telefono.trim().length < 9) return 'Teléfono inválido';
        return null;
      case 1:
        if (d.nombres.trim().isEmpty) return 'Ingrese nombres';
        if (d.apellidos.trim().isEmpty) return 'Ingrese apellidos';
        if (!RegExp(r'^\d{8}$').hasMatch(d.dni.trim())) {
          return 'DNI debe tener 8 dígitos';
        }
        if (d.fechaNacimiento == null) return 'Seleccione fecha de nacimiento';
        final edad = d.edad;
        if (edad == null || edad < 18 || edad > 75) {
          return 'Edad debe estar entre 18 y 75 años';
        }
        if (d.requiereConyuge) {
          if (d.conyugeNombres.trim().isEmpty) return 'Datos del cónyuge requeridos';
          if (!RegExp(r'^\d{8}$').hasMatch(d.conyugeDni.trim())) {
            return 'DNI del cónyuge: 8 dígitos';
          }
        }
        if (d.incluirGarante) {
          if (d.garanteNombres.trim().isEmpty) return 'Datos del garante requeridos';
          if (!RegExp(r'^\d{8}$').hasMatch(d.garanteDni.trim())) {
            return 'DNI del garante: 8 dígitos';
          }
        }
        return null;
      case 2:
        if (d.tipoNegocio.trim().isEmpty) return 'Tipo de negocio requerido';
        if (d.antiguedadMeses < 6) return 'Antigüedad mínima 6 meses';
        if (d.ingresosEstimados <= 0) return 'Ingresos inválidos';
        if (d.gastosEstimados < 0) return 'Gastos inválidos';
        if (d.destinoCredito.trim().isEmpty) return 'Destino del crédito requerido';
        if (d.destinoCredito.length > 500) {
          return 'Destino máximo 500 caracteres';
        }
        if (d.codigoCiiu.trim().isEmpty) return 'Código CIIU requerido';
        if (d.monto < 500 || d.monto > 150000) {
          return 'Monto entre S/ 500 y S/ 150,000';
        }
        if (![3, 6, 12, 18, 24, 36, 48, 60].contains(d.plazoMeses)) {
          return 'Plazo no válido';
        }
        return null;
      case 3:
        if (d.firmaBase64 == null || d.firmaBase64!.isEmpty) {
          return 'Firma digital requerida';
        }
        if (!d.declaracionJurada) return 'Debe aceptar la declaración jurada';
        return null;
      default:
        return null;
    }
  }

  bool siguiente() {
    final err = validarPaso(_paso);
    if (err != null) {
      _mensaje = err;
      notifyListeners();
      return false;
    }
    _mensaje = null;
    if (_paso < 3) {
      _paso++;
      if (_data != null) _data!.pasoActual = _paso;
    }
    notifyListeners();
    return true;
  }

  void anterior() {
    if (_paso > 0) {
      _paso--;
      if (_data != null) _data!.pasoActual = _paso;
      _mensaje = null;
      notifyListeners();
    }
  }

  Future<String?> guardarBorrador() async {
    if (_data == null) return 'Sin datos';
    _guardando = true;
    notifyListeners();
    _data!.pasoActual = _paso;
    final id = await _service.borradorDb.guardarBorrador(_data!);
    _data!.borradorIdLocal = id;
    _guardando = false;
    notifyListeners();
    return null;
  }

  /// ID de solicitud creada en servidor, o null si quedó en cola offline.
  Future<String?> enviarSolicitud() async {
    final err = validarPaso(3);
    if (err != null) {
      _mensaje = err;
      notifyListeners();
      return null;
    }
    _enviando = true;
    _mensaje = null;
    notifyListeners();

    String? solicitudId;
    try {
      solicitudId = await _service.enviarSolicitud(_data!);
      await refrescarPendientes();
    } catch (e) {
      _mensaje = e.toString().replaceFirst('Exception: ', '');
      solicitudId = null;
    }

    _enviando = false;
    if (solicitudId == null && _mensaje == null) {
      _mensaje = 'Pendiente de envío — se enviará al reconectar';
    }
    notifyListeners();
    return solicitudId;
  }

  Future<void> cargarBorradores(String asesorid) async {
    _borradores = await _service.borradorDb.listarPorAsesor(asesorid);
    notifyListeners();
  }

  Future<void> eliminarBorrador(String id) async {
    await _service.borradorDb.eliminarBorrador(id);
    _borradores.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<SolicitudCreditoData?> cargarBorradorPorId(String id) async {
    return _service.borradorDb.cargarBorrador(id);
  }

  Future<void> refrescarPendientes() async {
    await _service.sincronizarColaPendiente();
    _pendientesEnvio = await _service.contarPendientesEnvio();
    notifyListeners();
  }
}
