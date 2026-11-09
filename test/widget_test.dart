import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_map_app/core/services/auth_service.dart';
import 'package:my_map_app/core/services/trip_service.dart';
import 'package:my_map_app/main.dart';
import 'package:my_map_app/screens/auth/login/login_screen.dart';
import 'package:my_map_app/screens/map/map_canvas/region_photo_overlay.dart';

void main() {
  testWidgets('初回ログイン画面表示・ゲスト参加でのサンプルデータ表示・思い出画面UIテスト', (
    WidgetTester tester,
  ) async {
    AuthService.instance.resetToInitialGate();
    TripService.instance.resetForTest();
    await tester.pumpWidget(const MyMapApp());

    // 0. 初回起動時はログイン画面が表示され、まだマップは表示されないこと
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('Googleアカウントでログイン'), findsOneWidget);
    expect(find.text('ゲストとして参加'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);

    // 「ゲストとして参加」を押すとマップ画面へ遷移し、サンプルデータが表示されること
    await tester.tap(find.text('ゲストとして参加'));
    await tester.pumpAndSettle();

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

    // 2. 左上メニュー要素：初期グループ「MyMap」および（開始・思い出・招待・共有）が表示されていること
    expect(find.text('MyMap'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);
    expect(find.text('思い出'), findsOneWidget);
    expect(find.text('招待する'), findsOneWidget);
    expect(find.text('共有する'), findsOneWidget);

    // 「MyMap」選択時は個人用のため招待できないこと
    await tester.tap(find.text('招待する'));
    await tester.pumpAndSettle();
    expect(find.text('「MyMap」は個人用のため招待できません'), findsOneWidget);
    expect(find.text('招待コード（英数大文字8桁）'), findsNothing);

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

    // 5. 「思い出」ボタンをタップして思い出一覧画面へ遷移し、作成した旅行まとめが表示されること
    await tester.tap(find.text('思い出'));
    await tester.pumpAndSettle();

    expect(find.text('思い出一覧'), findsOneWidget);
    expect(find.text('週末の箱根旅'), findsOneWidget);

    // 6. 作成した旅行まとめをタップして詳細画面（スケッチUI）を開くこと
    await tester.tap(find.text('週末の箱根旅'));
    await tester.pumpAndSettle();

    expect(find.text('週末の箱根旅'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
  });

  testWidgets('ログイン画面：ログイン前はサインインボタンのみ、ログイン後はログアウトボタンのみ表示されること', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          currentUserName: 'DevFest ゲスト',
          onSignInCompleted: (_) {},
        ),
      ),
    );

    // 1. ログイン前：サインインボタンのみ表示され、ログアウトボタンは表示されないこと
    expect(find.text('Googleアカウントでログイン'), findsOneWidget);
    expect(find.text('ログアウト / ゲストに戻る'), findsNothing);

    // 2. サインインボタンをタップしてログインした後は、ログアウトボタンのみ表示されること
    await tester.tap(find.text('Googleアカウントでログイン'));
    await tester.pumpAndSettle();

    expect(find.text('Googleアカウントでログイン'), findsNothing);
    expect(find.text('ログアウト / ゲストに戻る'), findsOneWidget);

    // 3. ログアウトボタンをタップした後は、再びサインインボタンのみ表示されること
    await tester.tap(find.text('ログアウト / ゲストに戻る'));
    await tester.pumpAndSettle();

    expect(find.text('Googleアカウントでログイン'), findsOneWidget);
    expect(find.text('ログアウト / ゲストに戻る'), findsNothing);
  });
}
