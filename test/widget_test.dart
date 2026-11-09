import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_map_app/core/models/memory_pin.dart';
import 'package:my_map_app/core/models/trip_memory.dart';
import 'package:my_map_app/core/services/auth_service.dart';
import 'package:my_map_app/core/services/location_tracking_service.dart';
import 'package:my_map_app/core/services/place_autocomplete_service.dart';
import 'package:my_map_app/core/services/trip_service.dart';
import 'package:my_map_app/main.dart';
import 'package:my_map_app/screens/auth/login/login_screen.dart';
import 'package:my_map_app/screens/map/map_canvas/region_photo_overlay.dart';
import 'package:my_map_app/screens/memories/create_memory_screen.dart';
import 'package:my_map_app/screens/record/review_input/review_input_section.dart';

void main() {
  testWidgets('初回ログイン画面表示・ゲスト参加でのサンプルデータ表示・思い出画面UIテスト', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // 削除対象ボタン（簡易地図・都道府県フォト）および「ホーム」文字が存在せず、ホームアイコンボタンとピンだけを見るボタンが存在すること
    expect(find.text('簡易地図'), findsNothing);
    expect(find.text('都道府県フォト'), findsNothing);
    expect(find.text('ホーム'), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byKey(const Key('quick_pin_only_button')), findsOneWidget);

    // ピンだけを見るボタンを押すと1倍でも即座に最前面ピンが表示され、地図の見た目（県シルエット表示）は再描画せず保たれること
    await tester.tap(find.byKey(const Key('quick_pin_only_button')));
    await tester.pumpAndSettle();
    expect(find.byType(RegionPhotoOverlay), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(RegionPhotoOverlay), findsOneWidget);

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

    // 旅行中は「記録する」と「旅行終了」が表示されること
    expect(find.text('記録する'), findsOneWidget);
    expect(find.text('旅行終了'), findsOneWidget);

    // 4. 「旅行終了」をタップすると、つけたタイトル「週末の箱根旅」で旅行まとめが作られること
    await tester.tap(find.text('旅行終了'));
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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AuthService.instance.enterGuestMode();
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

  testWidgets('旅行スタート〜終了の実ルート追跡、および思い出一覧右上の＋ボタンからの手動作成・距離反映テスト', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final streamController = StreamController<RoutePoint>.broadcast();
    addTearDown(() {
      LocationTrackingService.instance.mockCurrentLocationProvider = null;
      LocationTrackingService.instance.mockPositionStream = null;
      streamController.close();
    });

    final now = DateTime.now();
    LocationTrackingService.instance.mockCurrentLocationProvider = () async {
      return RoutePoint(
        latitude: 35.6812,
        longitude: 139.7671,
        timestamp: DateTime(now.year, now.month, now.day, 10, 0),
      );
    };
    LocationTrackingService.instance.mockPositionStream =
        streamController.stream;
    AuthService.instance.resetToInitialGate();
    TripService.instance.resetForTest();

    final cafePin = MemoryPin(
      id: 'pin_cafe_1',
      teamId: 'daily',
      placeName: '代官山 ブックカフェ',
      address: '東京都渋谷区猿楽町17-5',
      prefecture: '東京都',
      latitude: 35.6488,
      longitude: 139.6994,
      mapNormalizedPosition: const Offset(0.65, 0.57),
      startTime: '14:00',
      endTime: '16:00',
      rating: 4,
      comment: '読書しながら過ごせる落ち着いた空間。チーズケーキが濃厚。',
      photoLabels: const ['チーズケーキ', '本棚'],
      recordedDate: DateTime(2026, 11, 5),
    );
    await TripService.instance.savePin(cafePin);

    await tester.pumpWidget(const MyMapApp());

    await tester.tap(find.text('ゲストとして参加'));
    await tester.pumpAndSettle();

    // 1. 旅行スタートを押下すると現在位置を取得し、移動に合わせて地図上にルート線が引かれること
    await tester.tap(find.text('旅行スタート'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '皇居周辺ラン');
    await tester.tap(find.text('スタート'));
    await tester.pumpAndSettle();

    expect(LocationTrackingService.instance.isTracking, isTrue);

    // 移動した位置をストリームに流す
    streamController.add(
      RoutePoint(
        latitude: 35.6852,
        longitude: 139.7528,
        timestamp: DateTime(now.year, now.month, now.day, 10, 15),
      ),
    );
    streamController.add(
      RoutePoint(
        latitude: 35.6750,
        longitude: 139.7590,
        timestamp: DateTime(now.year, now.month, now.day, 10, 30),
      ),
    );
    await tester.pumpAndSettle();

    final mapDuringTrip = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(
      mapDuringTrip.polylines.any(
        (p) =>
            p.polylineId.value == 'active_trip_route' && p.points.length == 3,
      ),
      isTrue,
    );

    // 2. 旅行終了ボタンを押下するとルート記録がストップし、移動距離が反映された思い出が作られること
    await tester.tap(find.text('旅行終了'));
    await tester.pumpAndSettle();
    expect(LocationTrackingService.instance.isTracking, isFalse);

    // 3. 思い出一覧へ遷移し、右上に「＋」ボタンが存在すること
    await tester.tap(find.text('思い出'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);

    // 4. 右上の「＋」ボタンをタップすると、ダイアログではなく別ページ（CreateMemoryScreen）に遷移すること
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(CreateMemoryScreen), findsOneWidget);
    expect(find.text('思い出を新規作成'), findsOneWidget);
    expect(find.textContaining('対象レビュー：'), findsOneWidget);

    // 親切なタイムライン手順ガイドを開いて確認できること
    await tester.tap(find.textContaining('はじめての方へ：タイムラインの取り出し方'));
    await tester.pumpAndSettle();
    expect(find.text('スマホで「Google マップ」アプリを開きます'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('manual_memory_title_field')),
      '手動追加した代官山旅',
    );

    // GoogleタイムラインJSONを入力して実際の移動ルートと距離（1.6km）を反映
    const timelineJson = '''
[
  {"latitude": 35.6585, "longitude": 139.7013, "timestamp": "2026-11-05T13:30:00Z"},
  {"latitude": 35.6488, "longitude": 139.6994, "timestamp": "2026-11-05T14:30:00Z"},
  {"latitude": 35.6442, "longitude": 139.7031, "timestamp": "2026-11-05T16:00:00Z"}
]
''';
    await tester.enterText(
      find.byKey(const Key('manual_memory_timeline_json_field')),
      timelineJson,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('manual_memory_submit_button')),
    );
    await tester.tap(find.byKey(const Key('manual_memory_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('手動追加した代官山旅'), findsOneWidget);

    // 5. 作成した思い出を開くと、該当時間帯のレビュー・写真・距離表示が反映されていること
    await tester.tap(find.text('手動追加した代官山旅'));
    await tester.pumpAndSettle();

    expect(find.textContaining('代官山 ブックカフェ'), findsOneWidget);
    expect(find.text('1.7km'), findsOneWidget);
  });

  testWidgets('スポット検索の予測候補・住所リンク反映、およびレビュー追加時にルート線がピンに追従しないことのテスト', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlaceAutocompleteService.disableNetworkInTests = true;
    final streamController = StreamController<RoutePoint>.broadcast();
    addTearDown(() {
      PlaceAutocompleteService.disableNetworkInTests = false;
      LocationTrackingService.instance.mockCurrentLocationProvider = null;
      LocationTrackingService.instance.mockPositionStream = null;
      streamController.close();
    });

    LocationTrackingService.instance.mockCurrentLocationProvider = () async {
      return RoutePoint(
        latitude: 35.6812,
        longitude: 139.7671,
        timestamp: DateTime(2026, 11, 8, 12, 0),
      );
    };
    LocationTrackingService.instance.mockPositionStream =
        streamController.stream;

    AuthService.instance.resetToInitialGate();
    await tester.pumpWidget(const MyMapApp());
    await tester.tap(find.text('ゲストとして参加'));
    await tester.pumpAndSettle();

    // 旅行スタート（ルート点は1点のみ）
    await tester.tap(find.text('旅行スタート'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '京都スポット記録テスト');
    await tester.tap(find.text('スタート'));
    await tester.pumpAndSettle();

    expect(LocationTrackingService.instance.activeRoutePoints.length, 1);

    // 「記録する」を押して記録画面へ遷移
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    // 写真の「合計 X 枚」表示が存在しないこと
    expect(find.textContaining('合計 '), findsNothing);

    // 初期状態（未入力）では東京の住所や予測変換リストが表示されていないこと
    expect(find.byKey(const Key('selected_address_link')), findsNothing);
    expect(
      find.byKey(const Key('place_prediction_list_container')),
      findsNothing,
    );

    // 位置の共有で「しない」を選択すると、場所入力欄自体が非表示になること
    await tester.tap(find.text('しない'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place_search_text_field')), findsNothing);

    // 再び「レビューする」を選択すると入力欄が表示されること
    await tester.tap(find.text('レビューする'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place_search_text_field')), findsOneWidget);

    // ヒットしない文字列を打ち込んだ時は予測変換が表示されないこと
    await tester.enterText(
      find.byKey(const Key('place_search_text_field')),
      '存在しない架空のスポットXYZ999',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('place_prediction_list_container')),
      findsNothing,
    );

    // ジャンル名（「カフェ」「ラーメン」「美術館」など）や都道府県名単体ではヒットしないこと
    for (final genreQuery in ['カフェ', 'ラーメン', '美術館', '東京都']) {
      await tester.enterText(
        find.byKey(const Key('place_search_text_field')),
        genreQuery,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('place_prediction_list_container')),
        findsNothing,
      );
    }

    // ご飯屋さんの店舗名（「一蘭」など）で検索すると予測候補が出ること
    await tester.enterText(
      find.byKey(const Key('place_search_text_field')),
      '一蘭',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('place_prediction_list_container')),
      findsOneWidget,
    );
    expect(find.textContaining('一蘭 渋谷店'), findsOneWidget);

    // 「清水寺」と入力すると予測候補に「清水寺（京都府京都市東山区清水1丁目294）」が出てくること
    await tester.enterText(
      find.byKey(const Key('place_search_text_field')),
      '清水寺',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('place_prediction_list_container')),
      findsOneWidget,
    );
    expect(find.text('京都府京都市東山区清水1丁目294'), findsWidgets);

    // 予測候補内の「清水寺」候補をタップすると、住所リンクが設定され、入力中ではなくなるため予測候補一覧が閉じること
    final candidateItem = find.descendant(
      of: find.byKey(const Key('place_prediction_list_container')),
      matching: find.text('清水寺'),
    );
    await tester.tap(candidateItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selected_address_link')), findsOneWidget);
    expect(
      find.byKey(const Key('place_prediction_list_container')),
      findsNothing,
    );

    // 「しない」を選択すると住所入力欄と星評価は非表示になるが、口コミ入力欄は表示されたままであること
    await tester.tap(find.text('しない'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place_search_text_field')), findsNothing);
    expect(find.byType(ReviewInputSection), findsOneWidget);
    expect(find.text('口コミ'), findsOneWidget);
    expect(find.byTooltip('1つ星'), findsNothing);

    // 再度「レビューする」を選択すると復活すること
    await tester.tap(find.text('レビューする'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place_search_text_field')), findsOneWidget);
    expect(find.byTooltip('1つ星'), findsOneWidget);

    // 保存ボタンを押してマップ画面に戻る
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // レビュー（ピン）を追加しても、移動ルート（activeRoutePoints）はピンの場所（京都）に追従して増えていないこと
    expect(LocationTrackingService.instance.activeRoutePoints.length, 1);
  });

  testWidgets('レビュー個別削除、および思い出削除時の関連レビュー一括削除（チェックボックス選択式）テスト', (
    WidgetTester tester,
  ) async {
    AuthService.instance.resetToInitialGate();
    TripService.instance.resetForTest();

    final samplePin1 = MemoryPin(
      id: 'pin_drive_1',
      teamId: 'daily',
      placeName: '鎌倉 海岸通り',
      address: '神奈川県鎌倉市由比ガ浜',
      prefecture: '神奈川県',
      latitude: 35.3110,
      longitude: 139.5460,
      mapNormalizedPosition: const Offset(0.62, 0.63),
      startTime: '10:00',
      endTime: '12:00',
      rating: 5,
      comment: '海沿いのドライブが最高でした。',
      photoLabels: const ['海', '車'],
      recordedDate: DateTime.now(),
      tripId: 'trip_drive',
    );
    final samplePin2 = MemoryPin(
      id: 'pin_drive_2',
      teamId: 'daily',
      placeName: '江の島 展望台',
      address: '神奈川県藤沢市江の島',
      prefecture: '神奈川県',
      latitude: 35.2990,
      longitude: 139.4810,
      mapNormalizedPosition: const Offset(0.61, 0.64),
      startTime: '13:00',
      endTime: '15:00',
      rating: 4,
      comment: '展望台からの景色が綺麗でした。',
      photoLabels: const ['展望台'],
      recordedDate: DateTime.now(),
      tripId: 'trip_drive',
    );
    final sampleMemory = TripMemory(
      id: 'trip_drive',
      teamId: 'daily',
      title: '東京・鎌倉ドライブ旅',
      startDate: DateTime.now().subtract(const Duration(hours: 5)),
      endDate: DateTime.now(),
      pins: [samplePin1, samplePin2],
    );
    await TripService.instance.saveTrip(sampleMemory);
    await TripService.instance.savePin(samplePin1);
    await TripService.instance.savePin(samplePin2);

    await tester.pumpWidget(const MyMapApp());
    await tester.tap(find.text('ゲストとして参加'));
    await tester.pumpAndSettle();

    // 1. 「思い出」ボタンをタップして思い出一覧画面へ遷移
    await tester.tap(find.text('思い出'));
    await tester.pumpAndSettle();

    // サンプル旅行まとめを開く
    await tester.tap(find.text('東京・鎌倉ドライブ旅'));
    await tester.pumpAndSettle();

    // 2. レビュー行の個別削除ボタン（Icons.delete_outline）をタップ
    final singleReviewDeleteButtons = find.byIcon(Icons.delete_outline);
    // 最初のdelete_outlineはタイトル右横の「思い出全体の削除」、2つ目以降が個別レビューの削除ボタン
    expect(singleReviewDeleteButtons, findsWidgets);
    await tester.tap(singleReviewDeleteButtons.at(1));
    await tester.pumpAndSettle();

    // レビュー削除確認ダイアログ
    expect(find.text('レビューを削除'), findsOneWidget);
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    // 3. タイトル横のゴミ箱アイコン（思い出全体の削除）をタップ
    await tester.tap(singleReviewDeleteButtons.first);
    await tester.pumpAndSettle();

    // 「思い出を削除」ダイアログが表示され、関連レビューも削除するかチェックリストが出ること
    expect(find.text('思い出を削除'), findsOneWidget);
    expect(find.textContaining('この思い出に含まれるレビューも同時に削除しますか？'), findsOneWidget);

    // チェックボックスをONにして削除実行
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    // 思い出一覧に戻り、「東京・鎌倉ドライブ旅」が削除されていること
    expect(find.text('東京・鎌倉ドライブ旅'), findsNothing);
  });

  testWidgets('グループの削除/退出機能、ピンViewボタンのルートデータ抑止、および1倍移動中/ホームボタン押下時のホームタブ維持テスト', (
    WidgetTester tester,
  ) async {
    AuthService.instance.resetToInitialGate();
    TripService.instance.resetForTest();

    final kyotoPin = MemoryPin(
      id: 'pin_kyoto',
      teamId: 'daily',
      placeName: '嵐山 竹林の小径',
      address: '京都府京都市右京区嵯峨小倉山田淵山町',
      prefecture: '京都府',
      latitude: 35.0170,
      longitude: 135.6713,
      mapNormalizedPosition: const Offset(0.45, 0.62),
      startTime: '09:00',
      endTime: '11:00',
      rating: 5,
      comment: '早朝に訪問したため人が少なく、風が吹く音まで心地よかった。',
      photoLabels: const ['竹林'],
      recordedDate: DateTime.now(),
      tripId: 'trip_kyoto',
    );
    await TripService.instance.savePin(kyotoPin);

    await tester.pumpWidget(const MyMapApp());
    await tester.tap(find.text('ゲストとして参加'));
    await tester.pumpAndSettle();

    // 1. 1倍表示でマップ移動（ドラッグ操作）を行っても、HeaderMenuOverlay（ホームタブ）が表示されたままであること
    expect(find.text('MyMap'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);

    await tester.drag(find.byType(GoogleMap), const Offset(-100, -100));
    await tester.pump();
    expect(find.text('MyMap'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);

    // ホームボタンを押した瞬間もホームタブが表示されたままであること
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    expect(find.text('MyMap'), findsOneWidget);
    expect(find.text('旅行スタート'), findsOneWidget);

    // 2. ピンViewボタンを押下した時、ピンが最前面に表示され、ルートデータ（polylines）は出力されず、
    //    ピンをタップするとレビュー吹き出し（PinCalloutCard）が表示されること
    final googleMapFinder = find.byType(GoogleMap);
    await tester.tap(find.byKey(const Key('quick_pin_only_button')));
    await tester.pumpAndSettle();

    final pinOnlyMap = tester.widget<GoogleMap>(googleMapFinder);
    expect(pinOnlyMap.polylines.isEmpty, isTrue);

    final topPinMarker = find.byKey(const Key('top_pin_marker_pin_kyoto'));
    expect(topPinMarker, findsOneWidget);
    await tester.tap(topPinMarker);
    await tester.pumpAndSettle();

    expect(find.text('嵐山 竹林の小径'), findsOneWidget);
    expect(find.text('詳細'), findsOneWidget);

    // ホームボタンを押して戻す
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    // 3. グループ切替プルダウンから別グループ（箱根・伊豆温泉旅）へ切り替え
    await tester.tap(find.text('MyMap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('箱根・伊豆温泉旅'));
    await tester.pumpAndSettle();

    expect(find.text('箱根・伊豆温泉旅'), findsOneWidget);

    // 4. 再びプルダウンを開き、「「箱根・伊豆温泉旅」を削除」を選択して削除できること
    await tester.tap(find.text('箱根・伊豆温泉旅'));
    await tester.pumpAndSettle();

    expect(find.textContaining('箱根・伊豆温泉旅」を削除'), findsOneWidget);
    await tester.tap(find.textContaining('箱根・伊豆温泉旅」を削除'));
    await tester.pumpAndSettle();

    expect(find.text('グループを削除'), findsOneWidget);
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    // 削除後は自動的に個人用「MyMap」に切り替わっていること
    expect(find.text('MyMap'), findsOneWidget);

    // 5. 市区町村名の抽出（cityゲッター）の解決テスト
    expect(
      const MemoryPin(
        id: '1',
        teamId: 'd',
        placeName: 'カフェ',
        address: '東京都江東区青海1-2-3',
        prefecture: '東京都',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '江東区',
    );
    expect(
      const MemoryPin(
        id: '2',
        teamId: 'd',
        placeName: '鎌倉',
        address: '神奈川県鎌倉市由比ガ浜',
        prefecture: '神奈川県',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '鎌倉市',
    );
    expect(
      const MemoryPin(
        id: '3',
        teamId: 'd',
        placeName: '京都',
        address: '京都府京都市右京区嵯峨小倉山田淵山町',
        prefecture: '京都府',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '京都市',
    );
    expect(
      const MemoryPin(
        id: '4',
        teamId: 'd',
        placeName: '札幌',
        address: '北海道札幌市中央区北1条西2丁目',
        prefecture: '北海道',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '札幌市',
    );
    expect(
      const MemoryPin(
        id: '5',
        teamId: 'd',
        placeName: '箱根',
        address: '神奈川県足柄下郡箱根町湯本',
        prefecture: '神奈川県',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '箱根町',
    );
    expect(
      const MemoryPin(
        id: '6',
        teamId: 'd',
        placeName: '渋谷',
        address: '東京都渋谷区猿楽町17-5',
        prefecture: '東京都',
        latitude: 0,
        longitude: 0,
        mapNormalizedPosition: Offset.zero,
        startTime: '10:00',
        endTime: '11:00',
        comment: '',
        photoLabels: [],
      ).city,
      '渋谷区',
    );
  });
}
