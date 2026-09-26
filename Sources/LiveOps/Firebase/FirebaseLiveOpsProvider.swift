#if os(iOS) && !canImport(FirebaseRemoteConfig)
#error("LiveOpsFirebase must link FirebaseRemoteConfig on iOS; check the dependency condition in Package.swift")
#endif

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif
import LiveOpsStore
