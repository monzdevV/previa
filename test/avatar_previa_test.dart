import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:previa/features/profile/avatar_previa.dart';

void main() {
  Widget envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

  testWidgets('sin foto muestra las iniciales', (tester) async {
    await tester.pumpWidget(envolver(const AvatarPrevia(iniciales: 'AB')));
    expect(find.text('AB'), findsOneWidget);
  });

  testWidgets('con etiqueta se expone a los lectores de pantalla',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(envolver(
      const AvatarPrevia(iniciales: 'AB', etiqueta: 'Tu foto de perfil'),
    ));
    expect(find.bySemanticsLabel('Tu foto de perfil'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('sin etiqueta es decorativo y no duplica el nombre',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(envolver(const AvatarPrevia(iniciales: 'AB')));
    expect(find.bySemanticsLabel('AB'), findsNothing);
    semantica.dispose();
  });
}
