import '../models/carta_item.dart';

const cartaCausaLimena = CartaItem(
  id: 'carta1',
  nombrePlato: 'Causa Limeña',
  descripcion: 'Causa rellena de pollo con mayonesa de la casa',
  categoriaId: 'cat1',
  taperId: 't1',
  precioCliente: 15.0,
);

const cartaAnticuchos = CartaItem(
  id: 'carta2',
  nombrePlato: 'Anticuchos',
  descripcion: 'Anzuelos de corazón a la parrilla con papa y choclo',
  categoriaId: 'cat1',
  precioCliente: 18.0,
);

const cartaLomoSaltado = CartaItem(
  id: 'carta3',
  nombrePlato: 'Lomo Saltado',
  descripcion: 'Salteado de lomo con cebolla, tomate y papas fritas',
  categoriaId: 'cat2',
  taperId: 't2',
  precioCliente: 32.0,
);

const cartaAjiDeGallina = CartaItem(
  id: 'carta4',
  nombrePlato: 'Ají de Gallina',
  descripcion: 'Pollo deshilachado en crema de ají amarillo',
  categoriaId: 'cat2',
  taperId: 't1',
  precioCliente: 28.0,
);

// Sin precioCliente: se vende por presentación (ver mock_presentaciones.dart).
const cartaChichaMorada = CartaItem(
  id: 'carta5',
  nombrePlato: 'Chicha Morada',
  descripcion: 'Bebida de maíz morado con frutas y especias',
  categoriaId: 'cat3',
);

const cartaLimonada = CartaItem(
  id: 'carta6',
  nombrePlato: 'Limonada',
  descripcion: 'Limonada frappé endulzada al gusto',
  categoriaId: 'cat3',
);

const mockCartas = [
  cartaCausaLimena,
  cartaAnticuchos,
  cartaLomoSaltado,
  cartaAjiDeGallina,
  cartaChichaMorada,
  cartaLimonada,
];
