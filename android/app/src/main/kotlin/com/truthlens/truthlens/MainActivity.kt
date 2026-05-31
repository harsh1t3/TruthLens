package com.truthlens.truthlens

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        // Force-load the ONNX Runtime native library via the JVM linker
        // *before* the Dart engine attempts to dlopen it via FFI. System.loadLibrary
        // knows where the app's native lib directory lives on every Android version
        // (including those where APK-extracted libs are not on dlopen's default
        // search path). Once loaded into the process, the Dart side's
        // DynamicLibrary.open("libonnxruntime.so") resolves via the in-memory
        // linker cache and succeeds.
        init {
            try {
                System.loadLibrary("onnxruntime")
            } catch (t: Throwable) {
                // Swallow: if this throws on a device, the Dart side will surface a
                // clear "classifier unavailable" diagnostic instead of crashing.
                android.util.Log.e("TruthLens", "System.loadLibrary(onnxruntime) failed", t)
            }
        }
    }
}
