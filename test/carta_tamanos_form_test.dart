import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bijao/data/categorias_store.dart';
import 'package:frontend_bijao/data/subcategorias_store.dart';
import 'package:frontend_bijao/data/variantes_store.dart';
import 'package:frontend_bijao/models/carta_item.dart';
import 'package:frontend_bijao/models/carta_variante.dart';
import 'package:frontend_bijao/models/categoria_comida.dart';
import 'package:frontend_bijao/models/subcategoria.dart';
import 'package:frontend_bijao/screens/carta_form_screen.dart';
import 'package:frontend_bijao/widgets/app_switch.dart';
import 'package:frontend_bijao/widgets/campo_texto.dart';

const _plato = '01925b6a-9b1d-7234-a123-abcdef012345';
const _sub = '01925b6a-9b1d-7234-a123-abcdef0123aa';
const _cat = '01925b6a-9b1d-7234-a123-abcdef0123bb';
const _varExistente = '01925b6a-9b1d-7234-a123-abcdef0123cc';

CartaItem _item() => const CartaItem(
  id: _plato,
  nombrePlato: 'Ceviche',
  descripcion: '',
  categoriaId: _cat,
  categoriaNombre: 'Marina',
  subcategoriaIds: [_sub],
);

void main() {
  setUp(() {
    variantes.clear();
    categorias
      ..clear()
      ..add(const CategoriaComida(id: _cat, categoria: 'Marina'));
    subcategorias
      ..clear()
      ..add(
        const Subcategoria(
          id: _sub,
          subcategoria: 'Pescados',
          categoriaComidaId: _cat,
        ),
      );
  });

  tearDown(() {
    variantes.clear();
    categorias.clear();
    subcategorias.clear();
  });

  // Abre el formulario y devuelve lo que entrega al guardar.
  Future<void> abrir(
    WidgetTester tester,
    CartaItem item,
    void Function(ResultadoPlato?) alCerrar,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => alCerrar(
                  await Navigator.of(context).push<ResultadoPlato>(
                    MaterialPageRoute(
                      builder: (_) => CartaFormScreen(item: item),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  // El campo de texto (EditableText) cuya etiqueta es [etiqueta].
  Finder campo(String etiqueta) => find.descendant(
    of: find.ancestor(
      of: find.text(etiqueta),
      matching: find.byType(CampoTexto),
    ),
    matching: find.byType(EditableText),
  );

  Future<void> guardar(WidgetTester tester) async {
    final boton = find.text('Guardar cambios');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    // Sin esperar de más: el aviso de error se cierra solo a los 3 s.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('el interruptor muestra las filas y se pueden agregar más', (
    tester,
  ) async {
    await abrir(tester, _item(), (_) {});
    expect(find.text('Tiene variantes'), findsOneWidget);
    expect(find.text('Agregar variante'), findsNothing); // apagado: sin filas

    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    expect(find.text('Agregar variante'), findsOneWidget);
    expect(campo('Variante'), findsOneWidget);

    await tester.tap(find.text('Agregar variante'));
    await tester.pumpAndSettle();
    expect(campo('Variante'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guardar con variantes los devuelve con nombre y precio', (
    tester,
  ) async {
    ResultadoPlato? salida;
    await abrir(tester, _item(), (r) => salida = r);
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    await tester.enterText(campo('Variante'), 'Pequeño');
    await tester.enterText(campo('Precio'), '18');
    await tester.tap(find.text('Agregar variante'));
    await tester.pumpAndSettle();
    await tester.enterText(campo('Variante').last, 'Grande');
    await tester.enterText(campo('Precio').last, '28');
    await guardar(tester);

    final lista = salida!.variantes!;
    expect(lista.map((v) => v.nombre), ['Pequeño', 'Grande']);
    expect(lista.map((v) => v.precioCliente), [18, 28]);
    // Sin precio personal, vale lo mismo que el público.
    expect(lista.map((v) => v.precioPersonal), [18, 28]);
    expect(lista.every((v) => v.id.isEmpty && v.estado), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('con el interruptor activo y sin nombre no se guarda', (
    tester,
  ) async {
    ResultadoPlato? salida;
    var cerro = false;
    await abrir(tester, _item(), (r) {
      salida = r;
      cerro = true;
    });
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    await guardar(tester);
    expect(cerro, isFalse); // sigue abierto
    expect(salida, isNull);
    expect(
      find.text('Cada variante necesita su nombre y un precio válido.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('apagar el interruptor desactiva los tamaños que ya existían', (
    tester,
  ) async {
    variantes.add(
      const CartaVariante(
        id: _varExistente,
        cartaId: _plato,
        nombre: 'Personal',
        precioCliente: 25,
        precioPersonal: 25,
      ),
    );
    ResultadoPlato? salida;
    await abrir(tester, _item(), (r) => salida = r);
    // Ya tiene un tamaño activo: el interruptor empieza encendido.
    expect(campo('Variante'), findsOneWidget);
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('se desactivarán'), findsOneWidget);
    await guardar(tester);

    final v = salida!.variantes!.single;
    expect(v.id, _varExistente);
    expect(v.estado, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
