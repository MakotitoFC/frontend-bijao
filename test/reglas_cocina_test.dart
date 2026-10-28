import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/models/reglas_cocina.dart';

void main() {
  test('sin reglas sale todo', () {
    const r = ReglasCocina();
    expect(r.imprimePlato('limonada', 'bebidas'), true);
    expect(r.imprimeCategoria('bebidas'), true);
  });

  test('una categoría apagada deja fuera a sus platos, salvo excepciones', () {
    const r = ReglasCocina(
      categorias: {'bebidas': false},
      platos: {'limonada': true, 'aguaje': true},
    );
    expect(r.imprimePlato('gaseosa', 'bebidas'), false);
    expect(r.imprimePlato('limonada', 'bebidas'), true);
    expect(r.imprimePlato('aguaje', 'bebidas'), true);
    // Otra categoría no se toca.
    expect(r.imprimePlato('lomo', 'segundos'), true);
  });

  test('un plato puede quedar fuera aunque su categoría sí salga', () {
    const r = ReglasCocina(platos: {'paleta': false});
    expect(r.imprimePlato('paleta', 'helados'), false);
    expect(r.imprimePlato('helado', 'helados'), true);
  });

  test('viaja y se lee igual que lo guarda el servidor', () {
    const r = ReglasCocina(
      categorias: {'bebidas': false},
      platos: {'limonada': true},
    );
    final json = r.toJson();
    expect(json['categorias'], [
      {'categoria_id': 'bebidas', 'imprime': false},
    ]);
    expect(json['platos'], [
      {'carta_id': 'limonada', 'imprime': true},
    ]);
    expect(ReglasCocina.fromJson(json), r);
  });

  test('la copia es independiente y se compara por contenido', () {
    const base = ReglasCocina(categorias: {'a': false});
    final c = base.copia();
    expect(c, base);
    c.categorias['b'] = false;
    expect(c == base, false);
    expect(base.categorias.length, 1);
  });
}
