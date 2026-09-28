#include "napi/native_api.h"
#include "hdc.h"

#include <cstdio>
#include <cstring>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace {

std::string GetString(napi_env env, napi_value value) {
    size_t len = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::vector<char> buf(len + 1, 0);
    napi_get_value_string_utf8(env, value, buf.data(), buf.size(), nullptr);
    return std::string(buf.data());
}

// 按空格切分命令行，支持双引号包裹的参数
std::vector<std::string> ParseCommandLine(const std::string &cmd) {
    std::vector<std::string> args;
    std::istringstream iss(cmd);
    std::string arg;
    bool inQuotes = false;
    char ch = 0;
    while (iss >> std::noskipws >> ch) {
        if (ch == '"') {
            inQuotes = !inQuotes;
        } else if (ch == ' ' && !inQuotes) {
            if (!arg.empty()) {
                args.push_back(arg);
                arg.clear();
            }
        } else {
            arg += ch;
        }
    }
    if (!arg.empty()) {
        args.push_back(arg);
    }
    return args;
}

std::string ReadFileToString(const std::string &filePath) {
    std::string text;
    FILE *f = fopen(filePath.c_str(), "rb");
    if (f == nullptr) {
        return text;
    }
    char buf[4096];
    size_t n = 0;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        text.append(buf, n);
        if (text.size() > 512 * 1024) {
            break;
        }
    }
    fclose(f);
    return text;
}

struct CmdResult {
    std::string text;
};

// 在 JS 线程里把结果回调给 ArkTS
void CallJs(napi_env env, napi_value jsCb, void *context, void *data) {
    CmdResult *res = static_cast<CmdResult *>(data);
    if (env != nullptr && jsCb != nullptr && res != nullptr) {
        napi_value argv[1];
        napi_create_string_utf8(env, res->text.c_str(), res->text.size(), &argv[0]);
        napi_call_function(env, nullptr, jsCb, 1, argv, nullptr);
    }
    delete res;
}

}  // namespace

// hdcStartServer(tempDir)：在当前进程内拉起 hdc server 线程
static napi_value HdcStartServer(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::string tempDir = argc > 0 ? GetString(env, args[0]) : "";
    napi_value undef = nullptr;
    napi_get_undefined(env, &undef);
    if (tempDir.empty()) {
        return undef;
    }
    std::thread t([](std::string dir) {
        server(dir.c_str());
    }, tempDir);
    t.detach();
    return undef;
}

// hdcRun(cmd, tempDir, callback)：执行一条 hdc 命令，输出通过回调返回
static napi_value HdcRun(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr, nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_value undef = nullptr;
    napi_get_undefined(env, &undef);
    if (argc < 3) {
        return undef;
    }
    std::string cmdString = GetString(env, args[0]);
    std::string tempDir = GetString(env, args[1]);
    std::vector<std::string> params = ParseCommandLine(cmdString);

    napi_value resourceName = nullptr;
    napi_create_string_latin1(env, "hdcRun", NAPI_AUTO_LENGTH, &resourceName);
    napi_threadsafe_function tsfn = nullptr;
    napi_create_threadsafe_function(env, args[2], nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr, CallJs, &tsfn);

    std::thread t([params, tempDir, tsfn]() {
        std::string outPath = tempDir + "/hdc_out.txt";
        remove(outPath.c_str());

        std::vector<const char *> argv;
        argv.reserve(params.size() + 1);
        for (auto &p : params) {
            argv.push_back(p.c_str());
        }
        argv.push_back(nullptr);
        cmd(static_cast<int>(params.size()), argv.data(), tempDir.c_str());

        std::string text = ReadFileToString(outPath);
        if (text.empty()) {
            text = "(no output)";
        }
        CmdResult *res = new CmdResult{text};
        napi_call_threadsafe_function(tsfn, res, napi_tsfn_blocking);
        napi_release_threadsafe_function(tsfn, napi_tsfn_release);
    });
    t.detach();
    return undef;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"hdcStartServer", nullptr, HdcStartServer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"hdcRun", nullptr, HdcRun, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module HdcModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "hdc_z",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterHdcModule(void) {
    napi_module_register(&HdcModule);
}
