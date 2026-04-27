{
  "targets": [
    {
      "target_name": "addon",
      "sources": [ "src/native/addon.mm" ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")"
      ],
      "defines": [ "NAPI_CPP_EXCEPTIONS" ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "cxxflags": [ "-std=c++17" ],
      "xcode_settings": {
        "OTHER_LDFLAGS": [ "-framework", "EventKit", "-framework", "CoreGraphics", "-framework", "CoreLocation" ],
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
        "CLANG_ENABLE_OBJC_ARC": "YES"
      }
    }
  ]
}
