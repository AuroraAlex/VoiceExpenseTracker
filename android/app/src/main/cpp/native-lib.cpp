#include <jni.h>
#include <string>
#include <android/log.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

#define LOG_TAG "SherpaOnnx"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_initRecognizer(JNIEnv *env, jobject thiz, jobject assetManager) {
    LOGI("initRecognizer called");
    try {
        // 暂时返回成功，不实际初始化复杂的识别器
        LOGI("initRecognizer completed successfully");
        return JNI_TRUE;
    } catch (...) {
        LOGE("Exception in initRecognizer");
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_startStream(JNIEnv *env, jobject thiz) {
    LOGI("startStream called");
    try {
        LOGI("startStream completed successfully");
    } catch (...) {
        LOGE("Exception in startStream");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_feedAudio(JNIEnv *env, jobject thiz, jbyteArray audioData) {
    LOGI("feedAudio called");
    try {
        if (audioData == nullptr) {
            LOGE("audioData is null");
            return;
        }
        
        jsize length = env->GetArrayLength(audioData);
        LOGI("Received audio data length: %d", length);
        
    } catch (...) {
        LOGE("Exception in feedAudio");
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_stopStream(JNIEnv *env, jobject thiz) {
    LOGI("stopStream called");
    try {
        // 返回一个测试结果
        std::string result = "今天买了一杯咖啡花了25元";
        LOGI("Returning result: %s", result.c_str());
        return env->NewStringUTF(result.c_str());
    } catch (...) {
        LOGE("Exception in stopStream");
        return env->NewStringUTF("");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_voice_1expense_1tracker_MainActivity_destroyRecognizer(JNIEnv *env, jobject thiz) {
    LOGI("destroyRecognizer called");
    try {
        LOGI("destroyRecognizer completed successfully");
    } catch (...) {
        LOGE("Exception in destroyRecognizer");
    }
}