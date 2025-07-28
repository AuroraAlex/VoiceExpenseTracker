#include <jni.h>
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <android/log.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

// 如果实际项目中已经包含了sherpa-onnx库，则需要包含相应的头文件
// 这里我们使用模拟实现，因为无法确定实际的sherpa-onnx库路径

#define LOG_TAG "SherpaOnnx"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// 模拟Sherpa-ONNX识别器类
class SherpaOnnxRecognizer {
public:
    SherpaOnnxRecognizer() : initialized_(false), streaming_(false) {}
    
    // 获取部分识别结果，不停止流
    std::string GetPartialResult() {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (!streaming_) {
            LOGE("Cannot get partial result: stream not started");
            return "";
        }
        
        LOGI("Getting partial recognition result");
        return current_result_;
    }
    
    bool Initialize(AAssetManager* assetManager) {
        LOGI("Initializing SherpaOnnxRecognizer");
        
        try {
            // 在实际实现中，这里需要:
            // 1. 从assets中加载模型文件
            // 2. 初始化Sherpa-ONNX识别器
            // 3. 设置识别参数
            
            // 模拟加载模型文件
            LOGI("Loading model files from assets");
            
            // 模拟初始化成功
            initialized_ = true;
            LOGI("SherpaOnnxRecognizer initialized successfully");
            return true;
        } catch (const std::exception& e) {
            LOGE("Exception during initialization: %s", e.what());
            return false;
        } catch (...) {
            LOGE("Unknown exception during initialization");
            return false;
        }
    }
    
    void StartStream() {
        std::lock_guard<std::mutex> lock(mutex_);
        LOGI("Starting recognition stream");
        
        if (!initialized_) {
            LOGE("Cannot start stream: recognizer not initialized");
            return;
        }
        
        // 清空当前的识别结果
        current_result_.clear();
        streaming_ = true;
    }
    
    void FeedAudio(const std::vector<uint8_t>& audio_data) {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (!streaming_) {
            LOGE("Cannot feed audio: stream not started");
            return;
        }
        
        LOGI("Processing audio chunk of size: %zu bytes", audio_data.size());
        
        // 在实际实现中，这里需要:
        // 1. 将音频数据转换为适合模型的格式
        // 2. 将数据传递给Sherpa-ONNX识别器
        // 3. 获取部分识别结果
        
        // 模拟识别过程
        // 根据音频数据长度模拟不同的识别结果
        if (audio_data.size() > 1000) {
            current_result_ = "正在识别中...";
        } else if (audio_data.size() > 500) {
            current_result_ = "我听到了一些声音";
        }
    }
    
    std::string StopStream() {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (!streaming_) {
            LOGE("Cannot stop stream: stream not started");
            return "";
        }
        
        LOGI("Stopping recognition stream");
        
        // 在实际实现中，这里需要:
        // 1. 通知Sherpa-ONNX识别器流结束
        // 2. 获取最终识别结果
        
        // 模拟最终识别结果
        // 如果当前没有结果，返回一个默认结果
        if (current_result_.empty()) {
            current_result_ = "今天买了一杯咖啡花了25元";
        }
        
        streaming_ = false;
        return current_result_;
    }
    
    void Destroy() {
        std::lock_guard<std::mutex> lock(mutex_);
        LOGI("Destroying SherpaOnnxRecognizer");
        
        if (streaming_) {
            StopStream();
        }
        
        // 在实际实现中，这里需要释放Sherpa-ONNX识别器的资源
        
        initialized_ = false;
    }
    
private:
    bool initialized_;
    bool streaming_;
    std::string current_result_;
    std::mutex mutex_;
};

// 全局识别器实例
std::unique_ptr<SherpaOnnxRecognizer> g_recognizer;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_initRecognizer(JNIEnv *env, jobject thiz, jobject assetManager) {
    LOGI("initRecognizer called");
    try {
        // 如果识别器已经存在，先销毁它
        if (g_recognizer) {
            g_recognizer->Destroy();
        }
        
        // 创建新的识别器实例
        g_recognizer = std::make_unique<SherpaOnnxRecognizer>();
        
        // 获取AAssetManager
        AAssetManager* native_asset_manager = AAssetManager_fromJava(env, assetManager);
        if (!native_asset_manager) {
            LOGE("Failed to get native asset manager");
            return JNI_FALSE;
        }
        
        // 初始化识别器
        bool success = g_recognizer->Initialize(native_asset_manager);
        LOGI("initRecognizer %s", success ? "succeeded" : "failed");
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in initRecognizer: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in initRecognizer");
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_startStream(JNIEnv *env, jobject thiz) {
    LOGI("startStream called");
    try {
        if (!g_recognizer) {
            LOGE("Recognizer not initialized");
            return;
        }
        
        g_recognizer->StartStream();
        LOGI("startStream completed successfully");
    } catch (const std::exception& e) {
        LOGE("Exception in startStream: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in startStream");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_feedAudio(JNIEnv *env, jobject thiz, jbyteArray audioData) {
    LOGI("feedAudio called");
    try {
        if (!g_recognizer) {
            LOGE("Recognizer not initialized");
            return;
        }
        
        if (audioData == nullptr) {
            LOGE("audioData is null");
            return;
        }
        
        // 获取音频数据
        jsize length = env->GetArrayLength(audioData);
        LOGI("Received audio data length: %d", length);
        
        if (length <= 0) {
            LOGE("Empty audio data");
            return;
        }
        
        // 将Java字节数组转换为C++向量
        std::vector<uint8_t> audio_vec(length);
        env->GetByteArrayRegion(audioData, 0, length, reinterpret_cast<jbyte*>(audio_vec.data()));
        
        // 处理音频数据
        g_recognizer->FeedAudio(audio_vec);
    } catch (const std::exception& e) {
        LOGE("Exception in feedAudio: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in feedAudio");
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_getPartialResult(JNIEnv *env, jobject thiz) {
    LOGI("getPartialResult called");
    try {
        if (!g_recognizer) {
            LOGE("Recognizer not initialized");
            return env->NewStringUTF("");
        }
        
        // 获取部分识别结果
        std::string result = g_recognizer->GetPartialResult();
        LOGI("Returning partial result: %s", result.c_str());
        return env->NewStringUTF(result.c_str());
    } catch (const std::exception& e) {
        LOGE("Exception in getPartialResult: %s", e.what());
        return env->NewStringUTF("");
    } catch (...) {
        LOGE("Unknown exception in getPartialResult");
        return env->NewStringUTF("");
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_stopStream(JNIEnv *env, jobject thiz) {
    LOGI("stopStream called");
    try {
        if (!g_recognizer) {
            LOGE("Recognizer not initialized");
            return env->NewStringUTF("");
        }
        
        // 获取识别结果
        std::string result = g_recognizer->StopStream();
        LOGI("Returning result: %s", result.c_str());
        return env->NewStringUTF(result.c_str());
    } catch (const std::exception& e) {
        LOGE("Exception in stopStream: %s", e.what());
        return env->NewStringUTF("");
    } catch (...) {
        LOGE("Unknown exception in stopStream");
        return env->NewStringUTF("");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_destroyRecognizer(JNIEnv *env, jobject thiz) {
    LOGI("destroyRecognizer called");
    try {
        if (g_recognizer) {
            g_recognizer->Destroy();
            g_recognizer.reset();
            LOGI("destroyRecognizer completed successfully");
        } else {
            LOGI("Recognizer already destroyed or not initialized");
        }
    } catch (const std::exception& e) {
        LOGE("Exception in destroyRecognizer: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in destroyRecognizer");
    }
}
