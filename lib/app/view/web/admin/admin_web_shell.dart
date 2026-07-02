import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../navigation/admin_web_routes.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/app_logo.dart';
import '../../../viewmodel/auth_oficial_viewmodel.dart';
import 'admin_cartera_screen.dart';
import 'admin_cobranza_screen.dart';
import 'admin_evaluacion_screen.dart';
import 'admin_inicio_screen.dart';
import 'admin_reportes_screen.dart';
import 'admin_solicitudes_screen.dart';

class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  String _rutaActual = AdminWebRoutes.inicio;

  static const _items = [
    _NavItem(
      id: AdminWebRoutes.inicio,
      titulo: 'Inicio',
      icono: Icons.home_outlined,
      iconoActivo: Icons.home,
    ),
    _NavItem(
      id: AdminWebRoutes.cartera,
      titulo: 'Cartera',
      icono: Icons.assignment_outlined,
      iconoActivo: Icons.assignment,
    ),
    _NavItem(
      id: AdminWebRoutes.solicitudes,
      titulo: 'Solicitudes',
      icono: Icons.description_outlined,
      iconoActivo: Icons.description,
    ),
    _NavItem(
      id: AdminWebRoutes.evaluacion,
      titulo: 'Evaluación',
      icono: Icons.fact_check_outlined,
      iconoActivo: Icons.fact_check,
    ),
    _NavItem(
      id: AdminWebRoutes.cobranza,
      titulo: 'Cobranza',
      icono: Icons.payments_outlined,
      iconoActivo: Icons.payments,
    ),
    _NavItem(
      id: AdminWebRoutes.reportes,
      titulo: 'Reportes',
      icono: Icons.bar_chart_outlined,
      iconoActivo: Icons.bar_chart,
    ),
  ];

  Future<void> _cerrarSesion() async {
    final vm = context.read<AuthOficialViewModel>();
    await vm.logout();
    if (!mounted) return;
    setState(() => _rutaActual = AdminWebRoutes.inicio);
  }

  void _navegar(String ruta) {
    setState(() => _rutaActual = ruta);
  }

  Widget _contenido() {
    switch (_rutaActual) {
      case AdminWebRoutes.cartera:
        return const AdminCarteraScreen();
      case AdminWebRoutes.solicitudes:
        return const AdminSolicitudesScreen();
      case AdminWebRoutes.evaluacion:
        return const AdminEvaluacionScreen();
      case AdminWebRoutes.cobranza:
        return const AdminCobranzaScreen();
      case AdminWebRoutes.reportes:
        return const AdminReportesScreen();
      case AdminWebRoutes.inicio:
      default:
        return AdminInicioScreen(onNavegar: _navegar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oficial = context.watch<AuthOficialViewModel>().oficial;
    if (oficial == null) return const SizedBox.shrink();

    final ancho = MediaQuery.sizeOf(context).width;
    final railExtendido = ancho >= 1100;

    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      body: Row(
        children: [
          NavigationRail(
            extended: railExtendido,
            minExtendedWidth: 200,
            minWidth: 72,
            backgroundColor: AppTheme.navyOscuro,
            selectedIndex: _items.indexWhere((i) => i.id == _rutaActual),
            onDestinationSelected: (i) => _navegar(_items[i].id),
            leading: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: railExtendido ? 12 : 0,
              ),
              child: Column(
                children: [
                  AppLogo(size: railExtendido ? 48 : 36),
                  if (railExtendido) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Portal Admin',
                      style: TextStyle(
                        color: AppTheme.amarillo,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: railExtendido
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.superficie,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${oficial.nombre} ${oficial.apellido}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                oficial.perfil.etiqueta,
                                style: const TextStyle(
                                  color: AppTheme.amarillo,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _cerrarSesion,
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    )
                  : IconButton(
                      onPressed: _cerrarSesion,
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Cerrar sesión',
                    ),
            ),
            selectedIconTheme: const IconThemeData(color: AppTheme.amarillo),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            indicatorColor: AppTheme.amarillo.withValues(alpha: 0.15),
            labelType: railExtendido
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            destinations: _items
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icono),
                    selectedIcon: Icon(item.iconoActivo),
                    label: Text(item.titulo),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }
}

class _NavItem {
  final String id;
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  const _NavItem({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.iconoActivo,
  });
}
