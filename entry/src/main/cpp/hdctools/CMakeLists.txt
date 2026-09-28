include_directories(include
    source/src/common
    source/src/host
    third_party/lz4/lib
    gen
    third_party/libusb/src/libusb-1.0.28
    third_party/libusb/src/libusb-1.0.28/libusb
)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -Wall")

add_subdirectory(third_party/lz4)

# ---------- libusb（来自仓库内置源码包，OpenHarmony 提供 linux/config.h）----------
set(LIBUSB_PKG ${CMAKE_CURRENT_SOURCE_DIR}/third_party/libusb)
set(LIBUSB_SRC ${LIBUSB_PKG}/src/libusb-1.0.28)
file(GLOB LIBUSB_CORE_SRCS ${LIBUSB_SRC}/libusb/*.c)
add_library(usb STATIC ${LIBUSB_CORE_SRCS}
    ${LIBUSB_SRC}/libusb/os/events_posix.c
    ${LIBUSB_SRC}/libusb/os/threads_posix.c
    ${LIBUSB_SRC}/libusb/os/linux_usbfs.c
    ${LIBUSB_SRC}/libusb/os/linux_netlink.c)
target_include_directories(usb PUBLIC ${LIBUSB_PKG}/linux)
target_include_directories(usb PRIVATE ${LIBUSB_SRC}/libusb)

add_definitions(-DHILOG -DHOST_OHOS -DHDC_SUPPORT_ENCRYPT_TCP -DHDC_SUPPORT_UART)
add_definitions(-DUSE_CONFIG_UV_THREADS -DSIZE_THREAD_POOL=128 -DHDC_HOST -DHARMONY_PROJECT)

AUX_SOURCE_DIRECTORY(${CMAKE_CURRENT_LIST_DIR}/source/src/host HOST_SRCS)
AUX_SOURCE_DIRECTORY(${CMAKE_CURRENT_LIST_DIR}/source/src/common COMMON_SRCS)
list(REMOVE_ITEM HOST_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/host/main.cpp")
list(REMOVE_ITEM COMMON_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/common/hdc_huks.cpp")
list(REMOVE_ITEM COMMON_SRCS "${CMAKE_CURRENT_LIST_DIR}/source/src/common/password.cpp")

add_library(hdc_z SHARED main.cpp hdc.h napi.cpp ${COMMON_SRCS} ${HOST_SRCS})

target_link_libraries(hdc_z
    libcrypto
    libssl
    lz4
    boundscheck
    uv
    usb
    hilog_ndk.z
    libace_napi.z.so
)
