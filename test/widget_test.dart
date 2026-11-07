import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_map_app/core/services/external_map_launcher.dart';
import 'package:my_map_app/main.dart';
import 'package:my_map_app/screens/map/map_canvas/region_photo_overlay.dart';

void main() {
  testWidgets('1倍初期表示・左上メニュー・旅行名設定〜停止・思い出画面UIテスト', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyMapApp());

    // 1. 起動直後（1倍）：ピンは表示されず、方位磁石がOFFで、県の形に沿った写真オーバーレイが表示されること
    final googleMapFinder = find.byType(GoogleMap);
    expect(googleMapFinder, findsOneWidget);
    final initialMap = tester.widget<GoogleMap>(googleMapFinder);
    expect(initialMap.markers.isEmpty, isTrue);
    expect(initialMap.compassEnabled, isFalse);
    expect(find.byType(RegionPhotoOverlay), findsOneWidget);

    // 削除対象ボタン（簡易地図・都道府県フォト）および「ホーム」文字が存在せず、ホームアイコンボタンが存在すること
    expect(find.text('簡易地図'), findsNothing);
    expect(find.text('都道府県フォト'), findsNothing);
    expect(find.text('ホーム'), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    // 2. 左上メニュー要素（開始・思い出・招待・共有）が表示されていること
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);
    expect(find.text('思い出'), findsOneWidget);
    expect(find.text('招待する'), findsOneWidget);
    expect(find.text('共有する'), findsOneWidget);

    // 3. 「旅行スタート」をタップすると旅行名入力ダイアログが出ること
    await tester.tap(find.text('旅行スタート'));
    await tester.pumpAndSettle();
    expect(find.text('旅行をスタート'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '週末の箱根旅');
    await tester.tap(find.text('スタート'));
    await tester.pumpAndSettle();


    // 旅行中は「記録する」と「旅行停止」が表示されること
    expect(find.text('記録する'), findsOneWidget);
    expect(find.text('旅行停止'), findsOneWidget);


    // 4. 「旅行停止」をタップすると、つけたタイトル「週末の箱根旅」で旅行まとめが作られること
    await tester.tap(find.text('旅行停止'));
    await tester.pumpAndSettle();
    expect(find.text('旅行スタート'), findsOneWidget);

    // 5. 「思い出」ボタンをタップして思い出一覧画面へ遷移すること
    await tester.tap(find.text('思い出'));
    await tester.pumpAndSettle();

    expect(find.text('思い出一覧'), findsOneWidget);
    expect(find.text('週末の箱根旅'), findsOneWidget);
    expect(find.text('東京・鎌倉ドライブ旅'), findsOneWidget);

    // 6. サンプル旅行まとめをタップして詳細画面（スケッチUI）を開くこと
    await tester.tap(find.text('東京・鎌倉ドライブ旅'));
    await tester.pumpAndSettle();

    expect(find.text('東京・鎌倉ドライブ旅'), findsOneWidget);
    expect(find.text('レビュー'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.north_east), findsWidgets);

    // 7. レビューが高評価順（★5 → ★4 → ★0）に並んでいること
    final rating5Y = tester
        .getTopLeft(find.textContaining('清澄白河 ロースタリーカフェ'))
        .dy;
    final rating4Y = tester
        .getTopLeft(find.textContaining('七里ヶ浜 海沿いテラス'))
        .dy;
    final rating0Y = tester
        .getTopLeft(find.textContaining('移動中継地点（海ほたるPA）'))
        .dy;
    expect(rating5Y, lessThan(rating4Y));
    expect(rating4Y, lessThan(rating0Y));

    // 8. 下部写真一覧が3列グリッド（SliverGrid）で描画され、写真説明テキストが出ないこと
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('ラテアート'), findsNothing);

    // 9. レビュー右端の「↗」をタップすると登録住所（東京都江東区清澄1-4-8）でGoogle Maps起動が要求されること
    await tester.tap(find.byIcon(Icons.north_east).first);
    await tester.pump();
    expect(ExternalMapLauncher.lastLaunchedQuery, '東京都江東区清澄1-4-8');
  });
}
