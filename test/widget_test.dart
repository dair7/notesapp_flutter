// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:notes_app/main.dart';

void main() {
  testWidgets('NotasProApp muestra la interfaz principal', (WidgetTester tester) async {
    // Construye la aplicación y genera un frame.
    await tester.pumpWidget(const NotasProApp());

    // Verifica que algún texto presente en la pantalla principal aparezca.
    // Elegimos el encabezado que siempre está presente al iniciarse.
    expect(find.text('Resumen de tu día'), findsOneWidget);
  });
}
