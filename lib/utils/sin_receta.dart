// Quita la palabra "receta" de los textos de movimientos de inventario que ve el
// usuario ("Consumo por receta" → "Consumo", "Consumo receta 'AGUA'" →
// "Consumo 'AGUA'"). Sirve también para registros antiguos que ya traen la palabra.
String sinReceta(String texto) => texto
    .replaceAll(
      RegExp(r'\s*\b(?:por\s+)?recetas?\b', caseSensitive: false),
      '',
    )
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();
