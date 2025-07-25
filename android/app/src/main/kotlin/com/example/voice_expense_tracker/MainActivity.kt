package com.example.voice_expense_tracker

import android.content.res.AssetManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        init {
            // 确保本地库在使用前已加载
            System.loadLibrary("native-lib")
        }
    }

    private val CHANNEL = "com.example.voice_expense_tracker/sherpa"

    // --- JNI 方法声明 ---
    // 初始化识别器，需要 AssetManager 来读取模型文件
    external fun initRecognizer(assetManager: AssetManager): Boolean
    // 开始一个新的识别流
    external fun startStream()
    // 接收音频数据块
    external fun feedAudio(audioChunk: ByteArray)
    // 停止音频流并获取最终结果
    external fun stopStream(): String
    // 销毁识别器，释放资源
    external fun destroyRecognizer()


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initRecognizer" -> {
                    // 调用 JNI 初始化方法，传入 AssetManager
                    val success = initRecognizer(context.assets)
                    result.success(success)
                }
                "startStream" -> {
                    startStream()
                    result.success(null)
                }
                "feedAudio" -> {
                    val audioData = call.arguments as? ByteArray
                    if (audioData != null) {
                        feedAudio(audioData)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "音频数据为空", null)
                    }
                }
                "stopStream" -> {
                    val transcription = stopStream()
                    result.success(transcription)
                }
                "destroyRecognizer" -> {
                    destroyRecognizer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 在 Activity 销毁时，确保识别器也被销毁
        destroyRecognizer()
    }
}