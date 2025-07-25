cmake_minimum_required(VERSION 3.10.2)
project("voice_expense_tracker")

# --- Sherpa-ONNX ---
# 定义预编译库的正确路径（相对于 android/app/src/main/cpp/）
set(SHERPA_LIBS_DIR ${CMAKE_SOURCE_DIR}/../../../sherpa-onnx-libs)

# 指定头文件目录
include_directories(${SHERPA_LIBS_DIR}/include)

# 添加预编译的库
add_library(sherpa-onnx-c-api SHARED IMPORTED)
set_target_properties(sherpa-onnx-c-api PROPERTIES IMPORTED_LOCATION
    ${SHERPA_LIBS_DIR}/jniLibs/${ANDROID_ABI}/libsherpa-onnx-c-api.so)

add_library(onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime PROPERTIES IMPORTED_LOCATION
    ${SHERPA_LIBS_DIR}/jniLibs/${ANDROID_ABI}/libonnxruntime.so)
# --- End Sherpa-ONNX ---

# 我们的本地库
add_library(
    native-lib
    SHARED
    native-lib.cpp
)

# 查找系统库
find_library(
    log-lib
    log
)

find_library(
    android-lib
    android
)

# 链接所有库
target_link_libraries(
    native-lib
    sherpa-onnx-c-api
    onnxruntime
    ${log-lib}
    ${android-lib}
)