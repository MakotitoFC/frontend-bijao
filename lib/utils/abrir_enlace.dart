import 'package:url_launcher/url_launcher.dart';

// Abre un enlace (por ejemplo el PDF de un comprobante) en el navegador o la
// app que corresponda. Devuelve false si no se pudo abrir.
Future<bool> abrirEnlace(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
