import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/solicitud_credito_data.dart';

class SolicitudBandejaClienteResumen {
  final String id;
  final String nombres;
  final String apellidos;
  final String dni;
  final double monto;
  final String? tipoNegocio;
  final String? destinoCredito;
  final String? telefono;
  final String? direccionNegocio;
  final double? latitudNegocio;
  final double? longitudNegocio;
  final double? ingresosEstimados;
  final DateTime? createdAt;
  final String? origen;
  final String? estado;

  SolicitudBandejaClienteResumen({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.monto,
    this.tipoNegocio,
    this.destinoCredito,
    this.telefono,
    this.direccionNegocio,
    this.latitudNegocio,
    this.longitudNegocio,
    this.ingresosEstimados,
    this.createdAt,
    this.origen,
    this.estado,
  });

  String get nombreCliente => '$nombres $apellidos'.trim();

  bool get tieneCoordenadasNegocio =>
      latitudNegocio != null &&
      longitudNegocio != null &&
      latitudNegocio! >= -90 &&
      latitudNegocio! <= 90 &&
      longitudNegocio! >= -180 &&
      longitudNegocio! <= 180;

  factory SolicitudBandejaClienteResumen.fromJson(Map<String, dynamic> json) {
    return SolicitudBandejaClienteResumen(
      id: json['id']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      dni: json['dni']?.toString() ?? '',
      monto: _toDouble(json['monto']),
      tipoNegocio: json['tiponegocio']?.toString(),
      destinoCredito: json['destinocredito']?.toString(),
      telefono: json['telefono']?.toString(),
      direccionNegocio: json['direccionnegocio']?.toString(),
      latitudNegocio: _toNullableDouble(json['latitudnegocio']),
      longitudNegocio: _toNullableDouble(json['longitudnegocio']),
      ingresosEstimados: _toNullableDouble(json['ingresosestimados']),
      createdAt: DateTime.tryParse(json['createdat']?.toString() ?? ''),
      origen: json['origen']?.toString(),
      estado: json['estado']?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class ResultadoTomarSolicitud {
  final bool ok;
  final String? error;
  final SolicitudCreditoData? datos;

  const ResultadoTomarSolicitud({required this.ok, this.error, this.datos});
}

class BandejaListaResult {
  final List<SolicitudBandejaClienteResumen> items;
  final String? error;

  const BandejaListaResult({required this.items, this.error});
}

/// Bandeja compartida: solicitudes originadas por clientes (app cliente).
class SolicitudBandejaClienteService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _selectCols =
      'id, nombres, apellidos, dni, monto, tiponegocio, destinocredito, '
      'telefono, direccionnegocio, latitudnegocio, longitudnegocio, '
      'ingresosestimados, createdat, origen, estado';

  Future<BandejaListaResult> listarPendientes({int limit = 50}) async {
    try {
      final rows = await _client
          .from('solicitudescredito')
          .select(_selectCols)
          .or(
            'and(estado.eq.pendiente_operador,analistaasignado.is.null),'
            'and(estado.eq.enviada,origen.eq.app_cliente,asesorid.is.null),'
            'and(estado.eq.recibido_comite,origen.eq.app_cliente,asesorid.is.null)',
          )
          .order('createdat', ascending: false)
          .limit(limit);

      return BandejaListaResult(
        items: _mapRows(rows),
      );
    } catch (e) {
      return BandejaListaResult(items: [], error: e.toString());
    }
  }

  Future<BandejaListaResult> listarEnAtencion({
    required String asesorid,
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from('solicitudescredito')
          .select(_selectCols)
          .eq('asesorid', asesorid)
          .eq('estado', 'en_atencion')
          .order('createdat', ascending: false)
          .limit(limit);

      return BandejaListaResult(items: _mapRows(rows));
    } catch (e) {
      return BandejaListaResult(items: [], error: e.toString());
    }
  }

  Future<({int count, String? error})> contarPendientes() async {
    try {
      final rows = await _client
          .from('solicitudescredito')
          .select('id')
          .or(
            'and(estado.eq.pendiente_operador,analistaasignado.is.null),'
            'and(estado.eq.enviada,origen.eq.app_cliente,asesorid.is.null),'
            'and(estado.eq.recibido_comite,origen.eq.app_cliente,asesorid.is.null)',
          );
      return (count: (rows as List).length, error: null);
    } catch (e) {
      return (count: 0, error: e.toString());
    }
  }

  List<SolicitudBandejaClienteResumen> _mapRows(dynamic rows) {
    return (rows as List)
        .map((r) => SolicitudBandejaClienteResumen.fromJson(
              Map<String, dynamic>.from(r as Map),
            ))
        .toList();
  }

  /// Toma una solicitud del pool (concurrencia: solo si sigue pendiente).
  Future<ResultadoTomarSolicitud> tomarSolicitud({
    required String solicitudId,
    required String asesorid,
  }) async {
    try {
      final ahora = DateTime.now().toIso8601String();
      // 1. Obtener estado actual (evitamos .inFilter o .or en el UPDATE para sortear el bug de PostgREST)
      final actual = await _client
          .from('solicitudescredito')
          .select('estado')
          .eq('id', solicitudId)
          .maybeSingle();
          
      if (actual == null) {
        return const ResultadoTomarSolicitud(ok: false, error: 'Solicitud no encontrada');
      }

      final estadoActual = actual['estado'] as String?;
      if (!['pendiente_operador', 'enviada', 'recibido_comite'].contains(estadoActual)) {
        return const ResultadoTomarSolicitud(
          ok: false,
          error: 'Esta solicitud ya fue tomada o no está disponible',
        );
      }

      // 2. Actualizar asegurando atomicidad con .eq('estado', estadoActual)
      final updated = await _client
          .from('solicitudescredito')
          .update({
            'asesorid': asesorid,
            'estado': 'en_atencion',
            'updatedat': ahora,
          })
          .eq('id', solicitudId)
          .eq('estado', estadoActual!)
          .select()
          .maybeSingle();

      if (updated == null) {
        return const ResultadoTomarSolicitud(
          ok: false,
          error: 'Esta solicitud ya fue tomada por otro operador',
        );
      }

      final datos = SolicitudCreditoData.fromSupabaseRow(
        Map<String, dynamic>.from(updated as Map),
        asesorid: asesorid,
      );
      return ResultadoTomarSolicitud(ok: true, datos: datos);
    } catch (e) {
      return ResultadoTomarSolicitud(
        ok: false,
        error: 'No se pudo tomar la solicitud: $e',
      );
    }
  }

  Future<SolicitudCreditoData?> cargarParaContinuar({
    required String solicitudId,
    required String asesorid,
  }) async {
    try {
      final row = await _client
          .from('solicitudescredito')
          .select()
          .eq('id', solicitudId)
          .eq('asesorid', asesorid)
          .eq('estado', 'en_atencion')
          .maybeSingle();
      if (row == null) return null;
      return SolicitudCreditoData.fromSupabaseRow(
        Map<String, dynamic>.from(row),
        asesorid: asesorid,
      );
    } catch (_) {
      return null;
    }
  }
}
