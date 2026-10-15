import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Interruptor de la app: pista verde y perilla blanca con un check cuando está
// activo. Más bajo que el Switch de Material. Acepta los mismos parámetros que
// se usaban antes (los colores se ignoran: el estilo es único).
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  // Compatibilidad con el Switch de Material; no se usan.
  final Color? activeThumbColor;
  final Color? activeTrackColor;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
    this.activeTrackColor,
  });

  static const double ancho = 40;
  static const double alto = 22;
  static const double _perilla = 18;

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: habilitado,
      child: MouseRegion(
        cursor: habilitado ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: habilitado ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: habilitado ? 1 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: ancho,
              height: alto,
              padding: const EdgeInsets.all((alto - _perilla) / 2),
              decoration: BoxDecoration(
                color: value ? AppColors.primaryGreen : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(alto / 2),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _perilla,
                  height: _perilla,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: value ? 1 : 0,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fila con título, subtítulo opcional y un AppSwitch a la derecha (reemplaza a
// SwitchListTile).
class AppSwitchTile extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  // Compatibilidad con SwitchListTile; no se usan.
  final Color? activeThumbColor;
  final Color? activeTrackColor;
  final bool dense;

  const AppSwitchTile({
    super.key,
    this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    this.activeThumbColor,
    this.activeTrackColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: (contentPadding ?? const EdgeInsets.symmetric(horizontal: 16))
            .add(EdgeInsets.symmetric(vertical: dense ? 4 : 9)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 14),
                      child: title!,
                    ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        child: subtitle!,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// Casilla de verificación de la app: cuadro redondeado que se rellena de verde
// con un check. Se usa en tablas y listas de selección (por ejemplo, los
// permisos de cada rol).
class AppCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppCheck({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null;
    return Semantics(
      checked: value,
      enabled: habilitado,
      child: MouseRegion(
        cursor: habilitado ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: habilitado ? () => onChanged!(!value) : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Opacity(
              opacity: habilitado ? 1 : 0.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: value
                        ? AppColors.primaryGreen
                        : Colors.grey.shade400,
                    width: 1.4,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
