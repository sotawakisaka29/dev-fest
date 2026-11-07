/// Googleフォトおよび端末アルバムから選択された写真モデル
class AppPhoto {
  const AppPhoto({
    required this.id,
    required this.label,
    this.url,
    this.localPath,
    this.takenAt,
    this.isFromGooglePhotos = true,
  });

  /// 写真の一意識別子
  final String id;

  /// 写真のタイトル・ラベル（ファイル名など）
  final String label;

  /// プレビュー画像URL（GoogleフォトのリモートURL）
  final String? url;

  /// 端末ローカルの写真ファイルパス（端末アルバムから選択した場合）
  final String? localPath;

  /// 撮影日時
  final DateTime? takenAt;

  /// Googleフォトから選択されたかどうか
  final bool isFromGooglePhotos;

  AppPhoto copyWith({
    String? id,
    String? label,
    String? url,
    String? localPath,
    DateTime? takenAt,
    bool? isFromGooglePhotos,
  }) {
    return AppPhoto(
      id: id ?? this.id,
      label: label ?? this.label,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      takenAt: takenAt ?? this.takenAt,
      isFromGooglePhotos: isFromGooglePhotos ?? this.isFromGooglePhotos,
    );
  }
}
