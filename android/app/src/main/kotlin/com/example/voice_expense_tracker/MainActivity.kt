package com.example.voice_expense_tracker

import android.Manifest
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    companion object {
        init {
            // 确保本地库在使用前已加载
            System.loadLibrary("native-lib")
        }
        
        // 音频配置常量
        private const val SAMPLE_RATE = 16000 // Hz
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE_FACTOR = 2
    }

    private val SHERPA_CHANNEL = "com.example.voice_expense_tracker/sherpa"
    private val SHERPA_ONNX_CHANNEL = "com.example.voice_expense_tracker/sherpa_onnx"

    // --- JNI 方法声明 ---
    // 初始化识别器，需要 AssetManager 来读取模型文件
    external fun initRecognizer(assetManager: AssetManager): Boolean
    // 开始一个新的识别流
    external fun startStream()
    // 接收音频数据块
    external fun feedAudio(audioChunk: ByteArray)
    // 获取部分识别结果，不停止流
    external fun getPartialResult(): String
    // 停止音频流并获取最终结果
    external fun stopStream(): String
    // 销毁识别器，释放资源
    external fun destroyRecognizer()
    
    // 音频录制相关变量
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sherpaOnnxChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 原有的Sherpa通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHERPA_CHANNEL).setMethodCallHandler { call, result ->
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
        
        // 新增的Sherpa-ONNX通道
        sherpaOnnxChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHERPA_ONNX_CHANNEL)
        sherpaOnnxChannel?.setMethodCallHandler { call, result ->
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
                "startRecording" -> {
                    val success = startRecording()
                    result.success(success)
                }
                "stopRecording" -> {
                    stopRecording()
                    result.success(null)
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
    
    private fun startRecording(): Boolean {
        if (isRecording) {
            return true
        }
        
        // 检查麦克风权限
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        
        try {
            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT
            )
            
            val bufferSize = minBufferSize * BUFFER_SIZE_FACTOR
            
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                return false
            }
            
            isRecording = true
            
            // 在单独的线程中处理音频数据
            executor.execute {
                val buffer = ByteArray(bufferSize)
                audioRecord?.startRecording()
                
                while (isRecording) {
                    val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    
                    if (readSize > 0) {
                        // 将音频数据传递给C++层进行识别
                        feedAudio(buffer.copyOfRange(0, readSize))
                        
                        // 获取部分识别结果并发送到Flutter
                        val partialResult = getPartialResult() // 使用getPartialResult方法获取部分结果
                        
                        // 在主线程中发送结果
                        mainHandler.post {
                            sherpaOnnxChannel?.invokeMethod("onPartialResult", partialResult)
                        }
                    }
                }
            }
            
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
    
    private fun stopRecording() {
        isRecording = false
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 停止录音
        stopRecording()
        // 在 Activity 销毁时，确保识别器也被销毁
        destroyRecognizer()
        // 关闭线程池
        executor.shutdown()
    }
}