import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_logo.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';

/// Layout de inicio de sesión optimizado para escritorio web.
class LoginWebLayout extends StatelessWidget {
  final TextEditingController codigoController;
  final TextEditingController passController;
  final bool verPassword;
  final VoidCallback onTogglePassword;
  final String Function(Duration?) formatCountdown;

  const LoginWebLayout({
    super.key,
    required this.codigoController,
    required this.passController,
    required this.verPassword,
    required this.onTogglePassword,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final usarSplit = ancho >= 900;

    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      body: usarSplit ? _buildSplit(context) : _buildCentrado(context),
    );
  }

  Widget _buildSplit(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _HeroPanel()),
        Expanded(
          child: ColoredBox(
            color: AppTheme.navyOscuro.withValues(alpha: 0.4),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: _LoginCard(
                  codigoController: codigoController,
                  passController: passController,
                  verPassword: verPassword,
                  onTogglePassword: onTogglePassword,
                  formatCountdown: formatCountdown,
                  anchoMax: 420,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentrado(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const AppLogo(size: 72),
              const SizedBox(height: 32),
              _LoginCard(
                codigoController: codigoController,
                passController: passController,
                verPassword: verPassword,
                onTogglePassword: onTogglePassword,
                formatCountdown: formatCountdown,
                anchoMax: 440,
                mostrarEncabezado: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.navyOscuro,
            AppTheme.fondoOscuro,
            AppTheme.navy.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amarillo.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amarillo.withValues(alpha: 0.04),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(size: 80),
                  const SizedBox(height: 28),
                  const Text(
                    'Banco Pichincha Perú',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.amarillo.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Portal Oficial de Crédito',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.amarillo,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _HeroFeature(
                    icono: Icons.admin_panel_settings_outlined,
                    titulo: 'Panel administrativo',
                    descripcion:
                        'Supervisa expedientes y documentación de operadores',
                  ),
                  const SizedBox(height: 16),
                  _HeroFeature(
                    icono: Icons.folder_copy_outlined,
                    titulo: 'Revisión documental',
                    descripcion:
                        'Consulta los archivos adjuntados por el equipo de campo',
                  ),
                  const SizedBox(height: 16),
                  _HeroFeature(
                    icono: Icons.bar_chart_outlined,
                    titulo: 'Reportes y cartera',
                    descripcion:
                        'Accede a métricas, cobranza y estado de solicitudes',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _HeroFeature({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.amarillo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: AppTheme.amarillo, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descripcion,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  final TextEditingController codigoController;
  final TextEditingController passController;
  final bool verPassword;
  final VoidCallback onTogglePassword;
  final String Function(Duration?) formatCountdown;
  final double anchoMax;
  final bool mostrarEncabezado;

  const _LoginCard({
    required this.codigoController,
    required this.passController,
    required this.verPassword,
    required this.onTogglePassword,
    required this.formatCountdown,
    required this.anchoMax,
    this.mostrarEncabezado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthOficialViewModel>(
      builder: (context, vm, _) {
        final bloqueado = vm.isLockedOut;

        return Container(
          width: anchoMax,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mostrarEncabezado) ...[
                const Text(
                  'Banco Pichincha Perú',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.amarillo,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Portal Oficial de Crédito',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresa tus credenciales de empleado',
                style: TextStyle(fontSize: 13, color: AppTheme.grisMedio),
              ),
              const SizedBox(height: 28),
              if (bloqueado)
                _BloqueoCard(
                  countdown: formatCountdown(vm.lockoutRemaining),
                )
              else ...[
                TextField(
                  controller: codigoController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Código de empleado',
                    hintText: 'Ej: 100004',
                    counterText: '',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  obscureText: !verPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        verPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.amarillo,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  ),
                ),
                if (vm.errorMessage.isNotEmpty &&
                    vm.state == AuthOficialState.error) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(mensaje: vm.errorMessage),
                ],
                const SizedBox(height: 28),
                vm.state == AuthOficialState.loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.amarillo,
                        ),
                      )
                    : SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => vm.login(
                            codigoController.text.trim(),
                            passController.text.trim(),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('ACCEDER AL PORTAL'),
                        ),
                      ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BloqueoCard extends StatelessWidget {
  final String countdown;

  const _BloqueoCard({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_clock, color: Colors.redAccent, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Cuenta bloqueada temporalmente',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Demasiados intentos fallidos.\nReintenta en:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            countdown,
            style: const TextStyle(
              color: AppTheme.amarillo,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String mensaje;

  const _ErrorBanner({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
