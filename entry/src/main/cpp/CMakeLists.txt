cmake_minimum_required(VERSION 3.5.0)
project(hapinstaller)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(NOT CMAKE_OHOS_ARCH_ABI)
    set(CMAKE_OHOS_ARCH_ABI arm64-v8a)
endif()

# ---------- OpenSSL（ohos 静态库）----------
add_library(libssl STATIC IMPORTED)
set_target_properties(libssl PROPERTIES
    IMPORTED_LOCATION ${NATIVERENDER_ROOT_PATH}/third_party/openssl/ohos/${CMAKE_OHOS_ARCH_ABI}/libssl.a
    INTERFACE_INCLUDE_DIRECTORIES ${NATIVERENDER_ROOT_PATH}/third_party/openssl/include)

add_library(libcrypto STATIC IMPORTED)
set_target_properties(libcrypto PROPERTIES
    IMPORTED_LOCATION ${NATIVERENDER_ROOT_PATH}/third_party/openssl/ohos/${CMAKE_OHOS_ARCH_ABI}/libcrypto.a
    INTERFACE_INCLUDE_DIRECTORIES ${NATIVERENDER_ROOT_PATH}/third_party/openssl/include)

# ---------- securec ----------
file(GLOB BOUNDS_SRC ${NATIVERENDER_ROOT_PATH}/third_party/bounds_checking_function/src/*.c)
add_library(boundscheck STATIC ${BOUNDS_SRC})
target_include_directories(boundscheck PUBLIC
    ${NATIVERENDER_ROOT_PATH}/third_party/bounds_checking_function/include)

# ---------- hdc host 内核 ----------
add_subdirectory(hdctools)

# ---------- 端侧签名（hapsigner）----------
add_subdirectory(hapsigner)
