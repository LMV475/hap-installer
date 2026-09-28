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
        if (text.size() > 256 * 1024) {
            break;
        }
    }
    fclose(f);
    return text;
}

struct SignResult {
    int code;
    std::string text;
};

// 在 JS 线程里回调：(code, outputText) => void
void CallJs(napi_env env, napi_value jsCb, void *context, void *data) {
    SignResult *res = static_cast<SignResult *>(data);
    if (env != nullptr && jsCb != nullptr && res != nullptr) {
        napi_value argv[2];
        napi_create_int32(env, res->code, &argv[0]);
        napi_create_string_utf8(env, res->text.c_str(), res->text.size(), &argv[1]);
        napi_call_function(env, nullptr, jsCb, 2, argv, nullptr);
    }
    delete res;
}

}  // namespace

// signHap(cmd, tempDir, callback)：端侧签名，回调返回 (返回码, 工具输出)
static napi_value SignHap(napi_env env, napi_callback_info info) {
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
    napi_create_string_latin1(env, "signHap", NAPI_AUTO_LENGTH, &resourceName);
    napi_threadsafe_function tsfn = nullptr;
    // 注意：这里必须是 args[2]（JS 回调），上游写成 args[1] 导致回调永不触发
    napi_create_threadsafe_function(env, args[2], nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr, CallJs, &tsfn);

    std::thread t([params, tempDir, tsfn]() {
        std::string outPath = tempDir + "/sign_out.txt";
        FILE *sout = freopen(outPath.c_str(), "w", stdout);
        FILE *serr = freopen(outPath.c_str(), "a", stderr);
        (void)sout;
        (void)serr;

        std::vector<const char *> argv;
        argv.reserve(params.size() + 1);
        for (auto &p : params) {
            argv.push_back(p.c_str());
        }
        argv.push_back(nullptr);
        int ok = ParamsRunTool::ProcessCmd(const_cast<const char **>(argv.data()),
                                           static_cast<int>(params.size())) ? 0 : -1;
        fflush(stdout);
        fflush(stderr);

        std::string text = ReadFileToString(outPath);
        if (text.empty()) {
            text = "(no output)";
        }
        SignResult *res = new SignResult{ok, text};
        napi_call_threadsafe_function(tsfn, res, napi_tsfn_blocking);
        napi_release_threadsafe_function(tsfn, napi_tsfn_release);
    });
    t.detach();
    return undef;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"signHap", nullptr, SignHap, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module signtoolModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "signtool",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterSignModule(void) {
    napi_module_register(&signtoolModule);
}
