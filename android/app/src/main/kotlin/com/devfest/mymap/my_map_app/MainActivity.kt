package com.devfest.mymap.my_map_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.devfest.mymap/external_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openGoogleMaps") {
                    val encodedQuery = call.argument<String>("encodedQuery") ?: ""
                    val universalUrl = call.argument<String>("universalUrl")
                        ?: "https://www.google.com/maps/search/?api=1&query=$encodedQuery"

                    try {
                        // 1. Google Maps アプリを直接起動（geo:0,0?q=<住所>）
                        val geoUri = Uri.parse("geo:0,0?q=$encodedQuery")
                        val mapIntent = Intent(Intent.ACTION_VIEW, geoUri).apply {
                            setPackage("com.google.android.apps.maps")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (mapIntent.resolveActivity(packageManager) != null) {
                            startActivity(mapIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        // 2. フォールバック：ブラウザまたは対応アプリでユニバーサルURLを開く
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(universalUrl)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(browserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
