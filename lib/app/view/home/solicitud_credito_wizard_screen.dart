import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../model/preevaluacion_resultado_model.dart';
import '../../model/solicitud_credito_data.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/monto_editable_slider.dart';
import '../../ui/widgets/ubicacion_negocio_mapa_panel.dart';
import '../../core/buro_solicitud_gate.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';
import '../../viewmodel/solicitud_credito_viewmodel.dart';
import 'captura_documentos_screen.dart';

class SolicitudCreditoWizardScreen extends StatefulWidget {
  final SolicitudCreditoData? borradorExistente;
  final ProspectoSolicitudPrefill? prefill;

  const SolicitudCreditoWizardScreen({
    super.key,
    this.borradorExistente,
    this.prefill,
  });

  @override
  State<SolicitudCreditoWizardScreen> createState() =>
      _SolicitudCreditoWizardScreenState();
}

class _SolicitudCreditoWizardScreenState
    extends State<SolicitudCreditoWizardScreen> {
  final _pageController = PageController();
  final _sigController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.white,
    exportBackgroundColor: AppTheme.navyOscuro,
  );
  late final String _sessionKey;
  bool _vmListo = false;

  @override
  void initState() {
    super.initState();
    _sessionKey = _resolverSessionKey();
  }

  String _resolverSessionKey() {
    final existente = widget.borradorExistente;
    if (existente?.solicitudIdServidor != null &&
        existente!.solicitudIdServidor!.isNotEmpty) {
      return existente.solicitudIdServidor!;
    }
    if (existente?.borradorIdLocal != null &&
        existente!.borradorIdLocal!.isNotEmpty) {
      return existente.borradorIdLocal!;
    }
    if (widget.prefill != null) {
      return widget.prefill!.dni;
    }
    return 'nueva_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vmListo) return;

    final asesor = context.read<AuthOficialViewModel>().oficial?.asesorid;
    if (asesor == null) return;

    final vm = context.read<SolicitudCreditoViewModel>();
    if (widget.borradorExistente != null) {
      vm.iniciar(asesorid: asesor, existente: widget.borradorExistente);
    } else if (widget.prefill != null) {
      vm.iniciar(
        asesorid: asesor,
        existente: _dataDesdePrefill(widget.prefill!, asesor),
      );
    } else {
      vm.iniciar(asesorid: asesor);
    }
    vm.refrescarPendientes();

    _vmListo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(vm.paso);
      }
    });
  }

  SolicitudCreditoData _dataDesdePrefill(
    ProspectoSolicitudPrefill p,
    String asesorid,
  ) {
    final partes = p.nombres.trim().split(RegExp(r'\s+'));
    return SolicitudCreditoData(
      asesorid: asesorid,
      nombres: partes.isNotEmpty ? partes.first : p.nombres,
      apellidos: partes.length > 1 ? partes.sublist(1).join(' ') : '',
      dni: p.dni,
      tipoNegocio: p.tiponegocio,
      monto: p.monto.clamp(500, 150000),
      destinoCredito: p.destino,
      ingresosEstimados: p.ingresos,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  void _syncPagina(int paso) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(paso);
    }
  }

  SolicitudCreditoData _leerData(SolicitudCreditoViewModel vm) {
    return vm.data ?? SolicitudCreditoData();
  }

  @override
  Widget build(BuildContext context) {
    if (!_vmListo) {
      return const Scaffold(
        backgroundColor: AppTheme.fondoOscuro,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.amarillo),
        ),
      );
    }

    final vm = context.watch<SolicitudCreditoViewModel>();
    final data = vm.data;
    if (data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.amarillo)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPagina(vm.paso));

    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      appBar: AppBar(
        title: Text(
          'Solicitud de crédito (${vm.paso + 1}/4)',
          style: const TextStyle(
            color: AppTheme.amarillo,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        actions: [
          if (vm.pendientesEnvio > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: Text(
                    '${vm.pendientesEnvio} pendiente(s)',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
                  side: const BorderSide(color: Colors.orangeAccent),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _IndicadorPasos(pasoActual: vm.paso),
          if (vm.mensaje != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vm.mensaje!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Paso1Visita(
                  key: ValueKey('paso1_$_sessionKey'),
                  data: data,
                  onChanged: (d) => vm.actualizar(d),
                ),
                _Paso2Solicitante(
                  key: ValueKey('paso2_$_sessionKey'),
                  data: data,
                  onChanged: (d) => vm.actualizar(d),
                ),
                _Paso3NegocioYCondiciones(
                  key: ValueKey('paso3_$_sessionKey'),
                  data: data,
                  onChanged: (d) => vm.actualizar(d),
                ),
                _Paso4Confirmacion(
                  key: ValueKey('paso4_$_sessionKey'),
                  data: data,
                  sigController: _sigController,
                  onChanged: (d) => vm.actualizar(d),
                ),
              ],
                ),
                if (vm.enviando)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.amarillo),
                          SizedBox(height: 12),
                          Text(
                            'Enviando solicitud...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _BarraNavegacion(
            paso: vm.paso,
            guardando: vm.guardando,
            enviando: vm.enviando,
            onAnterior: vm.paso > 0 ? vm.anterior : null,
            onGuardarBorrador: () async {
              await vm.guardarBorrador();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Borrador guardado')),
              );
            },
            onSiguiente: () async {
              if (vm.paso == 0 && !data.sePudoVisitar) {
                final cerrar = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.superficie,
                    title: const Text('Visita no realizada', style: TextStyle(color: AppTheme.amarillo)),
                    content: const Text('Al no haber podido visitar al cliente en la ubicación del negocio, no es posible continuar con la evaluación. La solicitud se cerrará.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Cerrar solicitud', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (cerrar == true && context.mounted) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context, false);
                  }
                }
                return;
              }

              if (vm.paso < 3) {
                if (vm.paso == 1) {
                  final ok = await BuroSolicitudGate.validarAntesDeSolicitud(
                    context,
                    dni: data.dni,
                    nombres: '${data.nombres} ${data.apellidos}'.trim(),
                  );
                  if (!context.mounted || !ok) return;
                }
                if (vm.siguiente()) _syncPagina(vm.paso);
              } else {
                _finalizarEnvio(vm);
              }
            },
            esUltimoPaso: vm.paso == 3,
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarEnvio(SolicitudCreditoViewModel vm) async {
    if (!_sigController.isEmpty) {
      final bytes = await _sigController.toPngBytes();
      if (bytes != null && bytes.isNotEmpty) {
        final d = _leerData(vm);
        d.firmaBase64 = base64Encode(bytes);
        vm.actualizar(d);
      }
    } else {
      final d = _leerData(vm);
      d.firmaBase64 = null;
      vm.actualizar(d);
    }

    final solicitudId = await vm.enviarSolicitud();
    if (!mounted) return;

    if (solicitudId != null) {
      final data = vm.data!;
      final args = CapturaDocumentosArgs(
        solicitudId: solicitudId,
        tituloSolicitud: '${data.nombres} ${data.apellidos}'.trim(),
      );
      // Pantalla completa sobre el shell (evita pantalla negra al reemplazar rutas)
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => CapturaDocumentosScreen(args: args),
        ),
      );
      return;
    }

    final msg = vm.mensaje ?? 'No se pudo enviar la solicitud';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.redAccent,
      ),
    );
    // No hacer pop si el wizard está embebido en el menú (provocaba pantalla negra)
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, false);
    }
  }
}

class _IndicadorPasos extends StatelessWidget {
  final int pasoActual;
  const _IndicadorPasos({required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    const labels = ['Visita', 'Solicitante', 'Negocio', 'Confirmar'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(4, (i) {
          final activo = i <= pasoActual;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: activo ? AppTheme.amarillo : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    color: activo ? AppTheme.amarillo : Colors.white38,
                    fontSize: 9,
                    fontWeight: i == pasoActual ? FontWeight.bold : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BarraNavegacion extends StatelessWidget {
  final int paso;
  final bool guardando;
  final bool enviando;
  final VoidCallback? onAnterior;
  final VoidCallback onGuardarBorrador;
  final VoidCallback onSiguiente;
  final bool esUltimoPaso;

  const _BarraNavegacion({
    required this.paso,
    required this.guardando,
    required this.enviando,
    required this.onAnterior,
    required this.onGuardarBorrador,
    required this.onSiguiente,
    required this.esUltimoPaso,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: guardando ? null : onGuardarBorrador,
              icon: guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar borrador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.amarillo,
                side: const BorderSide(color: AppTheme.amarillo),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAnterior,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    child: const Text('ANTERIOR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (guardando || enviando) ? null : onSiguiente,
                    child: enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.navy,
                            ),
                          )
                        : Text(esUltimoPaso ? 'ENVIAR' : 'SIGUIENTE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paso 1: Visita y Ubicación ───────────────────────────────────────────────

class _Paso1Visita extends StatefulWidget {
  final SolicitudCreditoData data;
  final ValueChanged<SolicitudCreditoData> onChanged;

  const _Paso1Visita({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<_Paso1Visita> createState() => _Paso1VisitaState();
}

class _Paso1VisitaState extends State<_Paso1Visita> {
  late final TextEditingController _nombre;
  late final TextEditingController _dir;
  late final TextEditingController _telefono;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nombre = TextEditingController(text: d.nombreNegocio);
    _dir = TextEditingController(text: d.direccionNegocio);
    _telefono = TextEditingController(text: d.telefono);
  }

  void _emit() {
    final d = widget.data;
    d.nombreNegocio = _nombre.text.trim();
    d.direccionNegocio = _dir.text.trim();
    d.telefono = _telefono.text.trim();
    widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloPaso('Visita al Negocio y Ubicación'),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.amarillo.withValues(alpha: 0.3)),
            ),
            child: SwitchListTile(
              title: const Text(
                '¿Pudo visitar al cliente en la ubicación?',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Indique si se realizó la visita física al negocio del cliente.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              value: d.sePudoVisitar,
              activeColor: AppTheme.amarillo,
              onChanged: (v) {
                d.sePudoVisitar = v;
                _emit();
                setState(() {});
              },
            ),
          ),
          if (d.sePudoVisitar) ...[
            _Campo(controller: _nombre, label: 'Nombre del negocio', onChanged: (_) => _emit()),
            _Campo(controller: _dir, label: 'Dirección del negocio', onChanged: (_) => _emit()),
            _Campo(
              controller: _telefono,
              label: 'Teléfono',
              keyboard: TextInputType.phone,
              onChanged: (_) => _emit(),
            ),
            if (d.tieneCoordenadasNegocio) ...[
              const SizedBox(height: 8),
              UbicacionNegocioMapaPanel(
                latitud: d.latitudNegocio!,
                longitud: d.longitudNegocio!,
                direccionTexto: d.direccionNegocio,
                nombreNegocio: d.nombreNegocio,
                compacto: true,
              ),
            ],
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Atención: Al no haberse podido visitar al cliente, no será posible continuar con la evaluación del crédito.',
                style: TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// ─── Paso 2: Solicitante ──────────────────────────────────────────────────────

class _Paso2Solicitante extends StatefulWidget {
  final SolicitudCreditoData data;
  final ValueChanged<SolicitudCreditoData> onChanged;

  const _Paso2Solicitante({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<_Paso2Solicitante> createState() => _Paso2SolicitanteState();
}

class _Paso2SolicitanteState extends State<_Paso2Solicitante> {
  late final TextEditingController _nombres;
  late final TextEditingController _apellidos;
  late final TextEditingController _dni;
  late final TextEditingController _email;
  late final TextEditingController _conyugeNombres;
  late final TextEditingController _conyugeDni;
  late final TextEditingController _garanteNombres;
  late final TextEditingController _garanteDni;
  late final TextEditingController _garanteTel;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nombres = TextEditingController(text: d.nombres);
    _apellidos = TextEditingController(text: d.apellidos);
    _dni = TextEditingController(text: d.dni);
    _email = TextEditingController(text: d.email);
    _conyugeNombres = TextEditingController(text: d.conyugeNombres);
    _conyugeDni = TextEditingController(text: d.conyugeDni);
    _garanteNombres = TextEditingController(text: d.garanteNombres);
    _garanteDni = TextEditingController(text: d.garanteDni);
    _garanteTel = TextEditingController(text: d.garanteTelefono);
  }

  void _emit() {
    final d = widget.data;
    d.nombres = _nombres.text.trim();
    d.apellidos = _apellidos.text.trim();
    d.dni = _dni.text.trim();
    d.email = _email.text.trim();
    d.conyugeNombres = _conyugeNombres.text.trim();
    d.conyugeDni = _conyugeDni.text.trim();
    d.garanteNombres = _garanteNombres.text.trim();
    d.garanteDni = _garanteDni.text.trim();
    d.garanteTelefono = _garanteTel.text.trim();
    widget.onChanged(d);
  }

  Future<void> _elegirFecha() async {
    final inicial = widget.data.fechaNacimiento ?? DateTime(1990, 1, 1);
    final f = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (f != null) {
      widget.data.fechaNacimiento = f;
      _emit();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloPaso('Datos del solicitante'),
          _Campo(controller: _nombres, label: 'Nombres', onChanged: (_) => _emit()),
          _Campo(controller: _apellidos, label: 'Apellidos', onChanged: (_) => _emit()),
          _Campo(
            controller: _dni,
            label: 'DNI (8 dígitos)',
            keyboard: TextInputType.number,
            maxLength: 8,
            onChanged: (_) => _emit(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              d.fechaNacimiento == null
                  ? 'Fecha de nacimiento'
                  : 'Nacimiento: ${d.fechaNacimiento!.day}/${d.fechaNacimiento!.month}/${d.fechaNacimiento!.year}'
                      '${d.edad != null ? ' (${d.edad} años)' : ''}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.calendar_today, color: AppTheme.amarillo),
            onTap: _elegirFecha,
          ),
          _Dropdown(
            label: 'Estado civil',
            value: d.estadoCivil,
            items: const {
              'soltero': 'Soltero/a',
              'casado': 'Casado/a',
              'conviviente': 'Conviviente',
              'divorciado': 'Divorciado/a',
              'viudo': 'Viudo/a',
            },
            onChanged: (v) {
              d.estadoCivil = v;
              _emit();
              setState(() {});
            },
          ),
          _Dropdown(
            label: 'Grado de instrucción',
            value: d.gradoInstruccion,
            items: const {
              'primaria': 'Primaria',
              'secundaria': 'Secundaria',
              'tecnico': 'Técnico',
              'universitario': 'Universitario',
              'postgrado': 'Postgrado',
            },
            onChanged: (v) {
              d.gradoInstruccion = v;
              _emit();
            },
          ),
          _Campo(
            controller: _email,
            label: 'Email (opcional)',
            keyboard: TextInputType.emailAddress,
            onChanged: (_) => _emit(),
          ),
          if (d.requiereConyuge) ...[
            const SizedBox(height: 12),
            const Text(
              'Datos del cónyuge',
              style: TextStyle(color: AppTheme.amarillo, fontWeight: FontWeight.bold),
            ),
            _Campo(controller: _conyugeNombres, label: 'Nombres cónyuge', onChanged: (_) => _emit()),
            _Campo(
              controller: _conyugeDni,
              label: 'DNI cónyuge',
              maxLength: 8,
              keyboard: TextInputType.number,
              onChanged: (_) => _emit(),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Registrar garante', style: TextStyle(color: Colors.white70)),
            value: d.incluirGarante,
            activeThumbColor: AppTheme.amarillo,
            onChanged: (v) {
              d.incluirGarante = v;
              _emit();
              setState(() {});
            },
          ),
          if (d.incluirGarante) ...[
            _Campo(controller: _garanteNombres, label: 'Nombre garante', onChanged: (_) => _emit()),
            _Campo(
              controller: _garanteDni,
              label: 'DNI garante',
              maxLength: 8,
              keyboard: TextInputType.number,
              onChanged: (_) => _emit(),
            ),
            _Campo(controller: _garanteTel, label: 'Teléfono garante', onChanged: (_) => _emit()),
          ],
        ],
      ),
    );
  }
}

// ─── Paso 3: Negocio y Condiciones ────────────────────────────────────────────

class _Paso3NegocioYCondiciones extends StatefulWidget {
  final SolicitudCreditoData data;
  final ValueChanged<SolicitudCreditoData> onChanged;

  const _Paso3NegocioYCondiciones({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<_Paso3NegocioYCondiciones> createState() => _Paso3NegocioYCondicionesState();
}

class _Paso3NegocioYCondicionesState extends State<_Paso3NegocioYCondiciones> {
  late final TextEditingController _tipo;
  late final TextEditingController _ingresos;
  late final TextEditingController _gastos;
  late final TextEditingController _patrimonio;
  late final TextEditingController _destino;

  static const _ciiu = {
    '4711': '4711 — Comercio minorista',
    '5610': '5610 — Restaurantes',
    '4520': '4520 — Mantenimiento vehículos',
    '2599': '2599 — Fabricación metales',
    '6201': '6201 — Desarrollo software',
    '9602': '9602 — Peluquería y belleza',
  };

  static const _plazos = [3, 6, 12, 18, 24, 36, 48, 60];

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _tipo = TextEditingController(text: d.tipoNegocio);
    _ingresos = TextEditingController(
      text: d.ingresosEstimados > 0 ? d.ingresosEstimados.toStringAsFixed(0) : '',
    );
    _gastos = TextEditingController(
      text: d.gastosEstimados > 0 ? d.gastosEstimados.toStringAsFixed(0) : '',
    );
    _patrimonio = TextEditingController(
      text: d.patrimonio?.toStringAsFixed(0) ?? '',
    );
    _destino = TextEditingController(text: d.destinoCredito);
  }

  void _emit() {
    final d = widget.data;
    d.tipoNegocio = _tipo.text.trim();
    d.ingresosEstimados = double.tryParse(_ingresos.text.trim()) ?? 0;
    d.gastosEstimados = double.tryParse(_gastos.text.trim()) ?? 0;
    final pat = _patrimonio.text.trim();
    d.patrimonio = pat.isEmpty ? null : double.tryParse(pat);
    d.destinoCredito = _destino.text.trim();
    widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloPaso('Evaluación del negocio'),
          _Campo(controller: _tipo, label: 'Tipo de negocio', onChanged: (_) => _emit()),
          AntiguedadEditableSlider(
            value: d.antiguedadMeses,
            min: 6,
            max: 120,
            divisions: 19,
            onChanged: (v) {
              d.antiguedadMeses = v;
              _emit();
              setState(() {});
            },
          ),
          _Campo(
            controller: _ingresos,
            label: 'Ingresos estimados (S/)',
            keyboard: TextInputType.number,
            onChanged: (_) => _emit(),
          ),
          _Campo(
            controller: _gastos,
            label: 'Gastos estimados (S/)',
            keyboard: TextInputType.number,
            onChanged: (_) => _emit(),
          ),
          _Campo(
            controller: _patrimonio,
            label: 'Patrimonio (opcional, S/)',
            keyboard: TextInputType.number,
            onChanged: (_) => _emit(),
          ),
          _Campo(
            controller: _destino,
            label: 'Destino del crédito (máx. 500)',
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => _emit(),
          ),
          _Dropdown(
            label: 'Actividad CIIU',
            value: _ciiu.containsKey(d.codigoCiiu) ? d.codigoCiiu : '4711',
            items: _ciiu,
            onChanged: (v) {
              d.codigoCiiu = v;
              _emit();
            },
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          const _TituloPaso('Condiciones del crédito'),
          MontoEditableSlider(
            value: d.monto,
            min: 500,
            max: 150000,
            divisions: 1495,
            etiqueta: 'Monto',
            prefijo: d.moneda,
            onChanged: (v) {
              d.monto = v;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          const Text('Plazo (meses)', style: TextStyle(color: Colors.white54, fontSize: 12)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _plazos.map((p) {
              final sel = d.plazoMeses == p;
              return ChoiceChip(
                label: Text('$p'),
                selected: sel,
                selectedColor: AppTheme.amarillo.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: sel ? AppTheme.amarillo : Colors.white70,
                  fontWeight: sel ? FontWeight.bold : null,
                ),
                onSelected: (_) {
                  d.plazoMeses = p;
                  widget.onChanged(d);
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _Dropdown(
            label: 'Moneda',
            value: d.moneda,
            items: const {'PEN': 'Soles (PEN)', 'USD': 'Dólares (USD)'},
            onChanged: (v) {
              d.moneda = v;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          _Dropdown(
            label: 'Tipo de cuota',
            value: d.tipoCuota,
            items: const {
              'fija': 'Cuota fija',
              'gracia': 'Periodo de gracia',
              'balloon': 'Balloon',
            },
            onChanged: (v) {
              d.tipoCuota = v;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          _Dropdown(
            label: 'Garantía',
            value: d.tipoGarantia,
            items: const {
              'personal': 'Personal',
              'prendaria': 'Prendaria',
              'hipotecaria': 'Hipotecaria',
              'fiduciaria': 'Fiduciaria',
            },
            onChanged: (v) {
              d.tipoGarantia = v;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          Text(
            'TEA referencial: ${d.tea.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: d.incluyeSeguroDesgravamen,
            activeColor: AppTheme.amarillo,
            title: const Text(
              'Incluir seguro de desgravamen',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            subtitle: const Text(
              'La cuota incluye prima de seguro de desgravamen (0.1% del capital/mes).',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            onChanged: (v) {
              d.incluyeSeguroDesgravamen = v ?? false;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          Slider(
            value: d.tea.clamp(12, 48),
            min: 12,
            max: 48,
            divisions: 36,
            activeColor: AppTheme.amarillo,
            onChanged: (v) {
              d.tea = v;
              widget.onChanged(d);
              setState(() {});
            },
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.superficie,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.verdePendiente.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulador (amortización francesa)',
                  style: TextStyle(
                    color: AppTheme.amarillo,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _SimRow(
                  'Cuota mensual',
                  '${d.moneda} ${d.cuotaMensual.toStringAsFixed(2)}'
                  '${d.incluyeSeguroDesgravamen ? ' (con seguro de desgravamen)' : ''}',
                ),
                _SimRow('Total a pagar', '${d.moneda} ${d.totalPagar.toStringAsFixed(2)}'),
                _SimRow('Total intereses', '${d.moneda} ${d.totalIntereses.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                const Text(
                  'TM = (1+TEA)^(1/12)-1',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimRow extends StatelessWidget {
  final String label;
  final String value;
  const _SimRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Paso 4 ───────────────────────────────────────────────────────────────────

class _Paso4Confirmacion extends StatefulWidget {
  final SolicitudCreditoData data;
  final SignatureController sigController;
  final ValueChanged<SolicitudCreditoData> onChanged;

  const _Paso4Confirmacion({
    super.key,
    required this.data,
    required this.sigController,
    required this.onChanged,
  });

  @override
  State<_Paso4Confirmacion> createState() => _Paso4ConfirmacionState();
}

class _Paso4ConfirmacionState extends State<_Paso4Confirmacion> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloPaso('Confirmación'),
          _ResumenCard(
            titulo: 'Solicitante',
            lineas: [
              '${d.nombreCompleto} · DNI ${d.dni}',
              '${d.estadoCivil} · ${d.gradoInstruccion}',
              d.telefono,
            ],
          ),
          _ResumenCard(
            titulo: 'Negocio',
            lineas: [
              '${d.nombreNegocio} (${d.tipoNegocio})',
              d.direccionNegocio,
              if (d.tieneCoordenadasNegocio)
                'GPS: ${d.latitudNegocio!.toStringAsFixed(6)}, '
                    '${d.longitudNegocio!.toStringAsFixed(6)}',
              'Ingresos S/ ${d.ingresosEstimados.toStringAsFixed(0)}',
            ],
          ),
          if (d.tieneCoordenadasNegocio) ...[
            const SizedBox(height: 8),
            UbicacionNegocioMapaPanel(
              latitud: d.latitudNegocio!,
              longitud: d.longitudNegocio!,
              direccionTexto: d.direccionNegocio,
              nombreNegocio: d.nombreNegocio,
              compacto: true,
            ),
          ],
          _ResumenCard(
            titulo: 'Condiciones',
            lineas: [
              '${d.moneda} ${d.monto.toStringAsFixed(0)} · ${d.plazoMeses} meses',
              'Cuota ${d.cuotaMensual.toStringAsFixed(2)}'
              '${d.incluyeSeguroDesgravamen ? ' (con seguro de desgravamen)' : ''}'
              ' · TEA ${d.tea.toStringAsFixed(1)}%',
              'Garantía: ${d.tipoGarantia}',
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Firma digital',
            style: TextStyle(color: AppTheme.amarillo, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.amarillo.withValues(alpha: 0.4)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                controller: widget.sigController,
                backgroundColor: AppTheme.superficie,
              ),
            ),
          ),
          TextButton(
            onPressed: () => widget.sigController.clear(),
            child: const Text('Limpiar firma', style: TextStyle(color: Colors.white54)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: d.declaracionJurada,
            activeColor: AppTheme.amarillo,
            title: const Text(
              'Declaro bajo juramento que la información consignada es veraz.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            onChanged: (v) {
              d.declaracionJurada = v ?? false;
              widget.onChanged(d);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// ─── Widgets comunes ──────────────────────────────────────────────────────────

class _TituloPaso extends StatelessWidget {
  final String texto;
  const _TituloPaso(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppTheme.amarillo,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Campo({
    required this.controller,
    required this.label,
    this.keyboard,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboard,
        maxLength: maxLength,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          counterText: maxLength != null && maxLines > 1 ? null : '',
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.containsKey(value) ? value : items.keys.first,
        dropdownColor: AppTheme.superficie,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final String titulo;
  final List<String> lineas;

  const _ResumenCard({required this.titulo, required this.lineas});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.superficie,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppTheme.amarillo,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          ...lineas.map(
            (l) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
