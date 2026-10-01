// Todas las cartas de los juegos de bebida, unidas en una sola lista.
//
// Cada juego vive en su propio fichero (`retos_*.dart`).
import '../modelo_juegos.dart';
import 'retos_nhh.dart' as nhh;
import 'retos_yn.dart' as yn;
import 'retos_mp.dart' as mp;
import 'retos_vr.dart' as vr;
import 'retos_pf.dart' as pf;

const List<Reto> todosLosRetos = [
  ...nhh.retosNhh,
  ...yn.retosYn,
  ...mp.retosMp,
  ...vr.retosVr,
  ...pf.retosPf,
];
