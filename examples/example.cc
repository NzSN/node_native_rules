#define NAPI_DISABLE_CPP_EXCEPTIONS
#include <napi.h>

Napi::Value _Sort(const Napi::CallbackInfo& info) {
  return info.Env().Undefined();
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports["example"] = Napi::Function::New(env, _Sort);
  return exports;
}

NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init);
