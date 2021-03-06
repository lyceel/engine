// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "sky/engine/bindings/jni/jni_api.h"

#include "sky/engine/bindings/jni/dart_jni.h"

namespace blink {

int64_t JniApi::FromReflectedField(const JniObject* field) {
  Dart_Handle exception = nullptr;
  {
    ENTER_JNI();

    jfieldID result = env->FromReflectedField(field->java_object());
    if (CheckJniException(env, &exception)) goto fail;

    return reinterpret_cast<int64_t>(result);
  }
fail:
  Dart_ThrowException(exception);
  ASSERT_NOT_REACHED();
  return 0;
}

int64_t JniApi::FromReflectedMethod(const JniObject* method) {
  Dart_Handle exception = nullptr;
  {
    ENTER_JNI();

    jmethodID result = env->FromReflectedMethod(method->java_object());
    if (CheckJniException(env, &exception)) goto fail;

    return reinterpret_cast<int64_t>(result);
  }
fail:
  Dart_ThrowException(exception);
  ASSERT_NOT_REACHED();
  return 0;
}

PassRefPtr<JniObject> JniApi::GetApplicationContext() {
  ENTER_JNI();
  return JniObject::Create(env, base::android::GetApplicationContext());
}

PassRefPtr<JniObject> JniApi::GetClassLoader() {
  ENTER_JNI();
  return JniObject::Create(env, DartJni::class_loader());
}

} // namespace blink
