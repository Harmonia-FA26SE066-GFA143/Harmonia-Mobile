package com.harmonia.mobile.harmonia_mobile

import android.annotation.SuppressLint
import android.content.Context
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class ScoreEngravingFactory(
    private val messenger: BinaryMessenger,
    private val assetPath: String,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ScoreEngravingView(context, MethodChannel(messenger, "harmonia/score_engraving/$viewId"), assetPath)
}

@SuppressLint("SetJavaScriptEnabled")
private class ScoreEngravingView(
    context: Context,
    private val channel: MethodChannel,
    assetPath: String,
) : PlatformView {
    private val web = WebView(context)
    private var disposed = false

    init {
        web.settings.javaScriptEnabled = true
        web.settings.blockNetworkLoads = true
        web.settings.allowFileAccess = false
        web.settings.allowContentAccess = false
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true
        }
        web.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(message: String) {
                web.post {
                    if (!disposed) channel.invokeMethod("status", message)
                }
            }
        }, "ScoreStatus")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    web.loadUrl("file:///android_asset/$assetPath")
                    result.success(null)
                }
                "evaluate" -> web.evaluateJavascript(call.arguments as String) { result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = web

    override fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        web.removeJavascriptInterface("ScoreStatus")
        web.stopLoading()
        web.destroy()
    }
}
