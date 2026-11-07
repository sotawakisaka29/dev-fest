import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_map_app/main.dart';

void main() {
  testWidgets('Google Maps表示・マーカー構成および旅行開始→記録画面遷移テスト', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyMapApp());

    // GoogleMap ウィジェットが描画され、初期マーカー・ルート線が設定されていることを確認
    final googleMapFinder = find.byType(GoogleMap);
    expect(googleMapFinder, findsOneWidget);
    final initialMap = tester.widget<GoogleMap>(googleMapFinder);
    expect(initialMap.markers.length, 5);
    expect(initialMap.polylines.length, 1);
    expect(initialMap.circles.length, 1);

    // メイン画面の上部メニュー要素が表示されていることを確認
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);
    expect(find.text('招待する'), findsOneWidget);
    expect(find.text('共有する'), findsOneWidget);
    expect(find.text('詳細'), findsOneWidget);

    // 「旅行スタート」をタップすると「記録（予定追加）」に切り替わることを確認
    await tester.tap(find.text('旅行スタート'));
    await tester.pumpAndSettle();
    expect(find.text('記録（予定追加）'), findsOneWidget);

    // 「記録（予定追加）」をタップして記録画面へ遷移することを確認
    await tester.tap(find.text('記録（予定追加）'));
    await tester.pumpAndSettle();

    expect(find.text('記録'), findsOneWidget);
    expect(find.text('位置を共有する'), findsOneWidget);
    expect(find.text('しない'), findsOneWidget);
    expect(find.text('場所を入力'), findsOneWidget);
    expect(find.text('口コミ'), findsOneWidget);
    expect(find.text('写真'), findsOneWidget);
    expect(find.text('アルバムから選択'), findsOneWidget);
    expect(find.text('Googleフォトから選択'), findsOneWidget);

    // 「✓」アイコンで保存してメイン画面へ戻ることを確認
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('新しい思い出スポット'), findsOneWidget);

    // 新規追加されたピンが GoogleMap のマーカーに反映されていることを確認
    final updatedMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(updatedMap.markers.length, 6);
  });
}
