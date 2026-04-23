{
  "targets": [
    {
      "target_name": "addon",
      "sources": [ "src/native/addon.mm"],
      "cxxflags": [ "-std=c++11" ],
      "xcode_settings": {
        "OTHER_LDFLAGS": ["-framework", "EventKit"]
      }
    }
  ]
}
