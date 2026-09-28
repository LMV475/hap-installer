include_directories(include
    source/src/common
    source/src/host
    third_party/lz4/lib
    gen
)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -Wall")

add_subdirectory(third_party/lz4)

# ---------- 已移除 libusb（LGPL-2.1 合规）----------
# 全部 libusb 源码/头文件/链接均已删除；HDC_NO_USB 使 host_usb.h 退化为 no-op 桩类。
# 未纳入版本库的 source/ 目录改动以 patch 形式保存在本文件同目录（与本文件同级）：
#   fix_no_libusb.patch   （从 hdctools/source/ 目录用 patch -p1 应用）

add_definitions(-DHILOG -DHOST_OHOS -DHDC_SUPPORT_ENCRYPT_TCP -DHDC_SUPPORT_UART)
add_definitions(-DUSE_CONFIG_UV_THREADS -DSIZE_THREAD_POOL=128 -DHDC_HOST -DHARMONY_PROJECT)
add_definitions(-DHDC_NO_USB)

AUX_SOURCE_DIRECTORY(${CMAKE_CURRENT_LIST_DIR}/source/src/host HOST_SRCS)
AUX_SOURCE_DIRECTORY(${CMAKE_CURRENT_LIST_DIR}/source/src/common COMMON_SRCS)
list(REMOVE_ITEM HOST_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/host/main.cpp")
list(REMOVE_ITEM HOST_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/host/host_usb.cpp")
list(REMOVE_ITEM COMMON_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/common/hdc_huks.cpp")
list(REMOVE_ITEM COMMON_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/common/password.cpp")

add_library(hdc_z SHARED main.cpp hdc.h napi.cpp ${COMMON_SRCS} ${HOST_SRCS})

target_link_libraries(hdc_z
    libcrypto
    libssl
    lz4
    boundscheck
    uv
    hilog_ndk.z
    libace_napi.z.so
)
