import '../core/amortizacion_francesa.dart';

class SolicitudCreditoData {
  String? borradorIdLocal;
  /// ID en Supabase cuando el operador retoma una solicitud del cliente.
  String? solicitudIdServidor;
  String asesorid;

  // Paso 1
  String nombres;
  String apellidos;
  String dni;
  DateTime? fechaNacimiento;
  String estadoCivil;
  String gradoInstruccion;
  String telefono;
  String email;
  String conyugeNombres;
  String conyugeDni;
  bool incluirGarante;
  String garanteNombres;
  String garanteDni;
  String garanteTelefono;
  bool sePudoVisitar;

  // Paso 2
  String tipoNegocio;
  String nombreNegocio;
  String direccionNegocio;
  double? latitudNegocio;
  double? longitudNegocio;
  int antiguedadMeses;
  double ingresosEstimados;
  double gastosEstimados;
  double? patrimonio;
  String destinoCredito;
  String codigoCiiu;

  // Paso 3
  double monto;
  int plazoMeses;
  String moneda;
  String tipoCuota;
  String tipoGarantia;
  double tea;
  bool incluyeSeguroDesgravamen;

  // Paso 4
  String? firmaBase64;
  bool declaracionJurada;

  int pasoActual;

  SolicitudCreditoData({
    this.borradorIdLocal,
    this.solicitudIdServidor,
    this.asesorid = '',
    this.nombres = '',
    this.apellidos = '',
    this.dni = '',
    this.fechaNacimiento,
    this.estadoCivil = 'soltero',
    this.gradoInstruccion = 'secundaria',
    this.telefono = '',
    this.email = '',
    this.conyugeNombres = '',
    this.conyugeDni = '',
    this.incluirGarante = false,
    this.garanteNombres = '',
    this.garanteDni = '',
    this.garanteTelefono = '',
    this.sePudoVisitar = true,
    this.tipoNegocio = '',
    this.nombreNegocio = '',
    this.direccionNegocio = '',
    this.latitudNegocio,
    this.longitudNegocio,
    this.antiguedadMeses = 6,
    this.ingresosEstimados = 0,
    this.gastosEstimados = 0,
    this.patrimonio,
    this.destinoCredito = '',
    this.codigoCiiu = '4711',
    this.monto = 5000,
    this.plazoMeses = 12,
    this.moneda = 'PEN',
    this.tipoCuota = 'fija',
    this.tipoGarantia = 'personal',
    this.tea = 28,
    this.incluyeSeguroDesgravamen = true,
    this.firmaBase64,
    this.declaracionJurada = false,
    this.pasoActual = 0,
  });

  bool get requiereConyuge =>
      estadoCivil == 'casado' || estadoCivil == 'conviviente';

  bool get tieneCoordenadasNegocio =>
      latitudNegocio != null &&
      longitudNegocio != null &&
      latitudNegocio! >= -90 &&
      latitudNegocio! <= 90 &&
      longitudNegocio! >= -180 &&
      longitudNegocio! <= 180;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  double get cuotaMensual => AmortizacionFrancesa.calcularCuota(
        monto: monto,
        teaPorcentaje: tea,
        plazoMeses: plazoMeses,
        incluyeSeguroDesgravamen: incluyeSeguroDesgravamen,
      );

  double get totalPagar => AmortizacionFrancesa.totalAPagar(
        cuotaMensual: cuotaMensual,
        plazoMeses: plazoMeses,
      );

  double get totalIntereses => AmortizacionFrancesa.totalIntereses(
        monto: monto,
        totalPagar: totalPagar,
      );

  int? get edad {
    if (fechaNacimiento == null) return null;
    final hoy = DateTime.now();
    var e = hoy.year - fechaNacimiento!.year;
    if (hoy.month < fechaNacimiento!.month ||
        (hoy.month == fechaNacimiento!.month &&
            hoy.day < fechaNacimiento!.day)) {
      e--;
    }
    return e;
  }

  Map<String, dynamic> toJson() => {
        'borradorIdLocal': borradorIdLocal,
        'solicitudIdServidor': solicitudIdServidor,
        'asesorid': asesorid,
        'nombres': nombres,
        'apellidos': apellidos,
        'dni': dni,
        'fechaNacimiento': fechaNacimiento?.toIso8601String(),
        'estadoCivil': estadoCivil,
        'gradoInstruccion': gradoInstruccion,
        'telefono': telefono,
        'email': email,
        'conyugeNombres': conyugeNombres,
        'conyugeDni': conyugeDni,
        'incluirGarante': incluirGarante,
        'garanteNombres': garanteNombres,
        'garanteDni': garanteDni,
        'garanteTelefono': garanteTelefono,
        'sePudoVisitar': sePudoVisitar,
        'tipoNegocio': tipoNegocio,
        'nombreNegocio': nombreNegocio,
        'direccionNegocio': direccionNegocio,
        'latitudNegocio': latitudNegocio,
        'longitudNegocio': longitudNegocio,
        'antiguedadMeses': antiguedadMeses,
        'ingresosEstimados': ingresosEstimados,
        'gastosEstimados': gastosEstimados,
        'patrimonio': patrimonio,
        'destinoCredito': destinoCredito,
        'codigoCiiu': codigoCiiu,
        'monto': monto,
        'plazoMeses': plazoMeses,
        'moneda': moneda,
        'tipoCuota': tipoCuota,
        'tipoGarantia': tipoGarantia,
        'tea': tea,
        'incluyeSeguroDesgravamen': incluyeSeguroDesgravamen,
        'firmaBase64': firmaBase64,
        'declaracionJurada': declaracionJurada,
        'pasoActual': pasoActual,
      };

  factory SolicitudCreditoData.fromJson(Map<String, dynamic> json) {
    return SolicitudCreditoData(
      borradorIdLocal: json['borradorIdLocal']?.toString(),
      solicitudIdServidor: json['solicitudIdServidor']?.toString(),
      asesorid: json['asesorid']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      dni: json['dni']?.toString() ?? '',
      fechaNacimiento: json['fechaNacimiento'] != null
          ? DateTime.tryParse(json['fechaNacimiento'].toString())
          : null,
      estadoCivil: json['estadoCivil']?.toString() ?? 'soltero',
      gradoInstruccion: json['gradoInstruccion']?.toString() ?? 'secundaria',
      telefono: json['telefono']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      conyugeNombres: json['conyugeNombres']?.toString() ?? '',
      conyugeDni: json['conyugeDni']?.toString() ?? '',
      incluirGarante: json['incluirGarante'] == true,
      garanteNombres: json['garanteNombres']?.toString() ?? '',
      garanteDni: json['garanteDni']?.toString() ?? '',
      garanteTelefono: json['garanteTelefono']?.toString() ?? '',
      sePudoVisitar: json['sePudoVisitar'] != false,
      tipoNegocio: json['tipoNegocio']?.toString() ?? '',
      nombreNegocio: json['nombreNegocio']?.toString() ?? '',
      direccionNegocio: json['direccionNegocio']?.toString() ?? '',
      latitudNegocio: _toNullableDouble(json['latitudNegocio']),
      longitudNegocio: _toNullableDouble(json['longitudNegocio']),
      antiguedadMeses: json['antiguedadMeses'] is int
          ? json['antiguedadMeses'] as int
          : int.tryParse(json['antiguedadMeses']?.toString() ?? '') ?? 6,
      ingresosEstimados: _toDouble(json['ingresosEstimados']),
      gastosEstimados: _toDouble(json['gastosEstimados']),
      patrimonio: _toNullableDouble(json['patrimonio']),
      destinoCredito: json['destinoCredito']?.toString() ?? '',
      codigoCiiu: json['codigoCiiu']?.toString() ?? '4711',
      monto: _toDouble(json['monto'], 5000),
      plazoMeses: json['plazoMeses'] is int
          ? json['plazoMeses'] as int
          : int.tryParse(json['plazoMeses']?.toString() ?? '') ?? 12,
      moneda: json['moneda']?.toString() ?? 'PEN',
      tipoCuota: json['tipoCuota']?.toString() ?? 'fija',
      tipoGarantia: json['tipoGarantia']?.toString() ?? 'personal',
      tea: _toDouble(json['tea'], 28),
      incluyeSeguroDesgravamen: json['incluyeSeguroDesgravamen'] != false,
      firmaBase64: json['firmaBase64']?.toString(),
      declaracionJurada: json['declaracionJurada'] == true,
      pasoActual: json['pasoActual'] is int
          ? json['pasoActual'] as int
          : int.tryParse(json['pasoActual']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toSupabasePayload() => {
        'asesorid': asesorid,
        'estado': 'documentos_pendientes',
        'origen': solicitudIdServidor != null ? 'app_cliente' : 'app_ventas',
        'nombres': nombres,
        'apellidos': apellidos,
        'dni': dni,
        'fechanacimiento': fechaNacimiento!
            .toIso8601String()
            .split('T')
            .first,
        'estadocivil': estadoCivil,
        'gradoinstruccion': gradoInstruccion,
        'telefono': telefono,
        'email': email.isEmpty ? null : email,
        'conyugenombres': requiereConyuge ? conyugeNombres : null,
        'conyugedni': requiereConyuge ? conyugeDni : null,
        'garantenombres': incluirGarante ? garanteNombres : null,
        'garantedni': incluirGarante ? garanteDni : null,
        'garantetelefono': incluirGarante ? garanteTelefono : null,
        'tiponegocio': tipoNegocio,
        'nombrenegocio': nombreNegocio,
        'direccionnegocio': direccionNegocio,
        'latitudnegocio': ?latitudNegocio,
        'longitudnegocio': ?longitudNegocio,
        'antiguedadmeses': antiguedadMeses,
        'ingresosestimados': ingresosEstimados,
        'gastosestimados': gastosEstimados,
        'patrimonio': patrimonio,
        'destinocredito': destinoCredito,
        'codigociiu': codigoCiiu,
        'monto': monto,
        'plazomeses': plazoMeses,
        'moneda': moneda,
        'tipocuota': tipoCuota,
        'tipogarantia': tipoGarantia,
        'tea': tea,
        'incluyesegurodesgravamen': incluyeSeguroDesgravamen,
        'cuotamensual': cuotaMensual,
        'totalintereses': totalIntereses,
        'firmadigital': firmaBase64,
        'declaracionjurada': declaracionJurada,
      };

  /// Carga datos parciales enviados por el cliente para completar en campo.
  factory SolicitudCreditoData.fromSupabaseRow(
    Map<String, dynamic> json, {
    required String asesorid,
  }) {
    DateTime? fn;
    final fnRaw = json['fechanacimiento'];
    if (fnRaw != null) {
      fn = DateTime.tryParse(fnRaw.toString());
    }

    return SolicitudCreditoData(
      solicitudIdServidor: json['id']?.toString(),
      asesorid: asesorid,
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      dni: json['dni']?.toString() ?? '',
      fechaNacimiento: fn,
      estadoCivil: json['estadocivil']?.toString() ?? 'soltero',
      gradoInstruccion: json['gradoinstruccion']?.toString() ?? 'secundaria',
      telefono: json['telefono']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      conyugeNombres: json['conyugenombres']?.toString() ?? '',
      conyugeDni: json['conyugedni']?.toString() ?? '',
      garanteNombres: json['garantenombres']?.toString() ?? '',
      garanteDni: json['garantedni']?.toString() ?? '',
      garanteTelefono: json['garantetelefono']?.toString() ?? '',
      incluirGarante: (json['garantenombres']?.toString() ?? '').isNotEmpty,
      sePudoVisitar: true,
      tipoNegocio: json['tiponegocio']?.toString() ?? '',
      nombreNegocio: json['nombrenegocio']?.toString() ?? '',
      direccionNegocio: json['direccionnegocio']?.toString() ?? '',
      latitudNegocio: _toNullableDouble(json['latitudnegocio']),
      longitudNegocio: _toNullableDouble(json['longitudnegocio']),
      antiguedadMeses: json['antiguedadmeses'] is int
          ? json['antiguedadmeses'] as int
          : int.tryParse(json['antiguedadmeses']?.toString() ?? '') ?? 6,
      ingresosEstimados: _toDouble(json['ingresosestimados']),
      gastosEstimados: _toDouble(json['gastosestimados']),
      patrimonio: _toNullableDouble(json['patrimonio']),
      destinoCredito: json['destinocredito']?.toString() ?? '',
      codigoCiiu: json['codigociiu']?.toString() ?? '4711',
      monto: _toDouble(json['monto'], 5000),
      plazoMeses: json['plazomeses'] is int
          ? json['plazomeses'] as int
          : int.tryParse(json['plazomeses']?.toString() ?? '') ?? 12,
      moneda: json['moneda']?.toString() ?? 'PEN',
      tipoCuota: json['tipocuota']?.toString() ?? 'fija',
      tipoGarantia: json['tipogarantia']?.toString() ?? 'personal',
      tea: _toDouble(json['tea'], 28),
      incluyeSeguroDesgravamen: json['incluyesegurodesgravamen'] != false,
      firmaBase64: json['firmadigital']?.toString(),
      declaracionJurada: json['declaracionjurada'] == true,
      pasoActual: 0,
    );
  }

  static double _toDouble(dynamic v, [double def = 0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class SolicitudBorradorResumen {
  final String id;
  final String nombre;
  final int pasoAlcanzado;
  final String fechaActualizacion;
  final double monto;

  SolicitudBorradorResumen({
    required this.id,
    required this.nombre,
    required this.pasoAlcanzado,
    required this.fechaActualizacion,
    required this.monto,
  });
}
