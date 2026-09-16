# Development

## Requirements

Xcode 27 (iOS 27 SDK), [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). No other external dependencies.

## Commands

Domain logic tests (fast, no simulator, run these first when changing
anything in `AppGymKit`):

```sh
cd AppGymKit && swift test
```

Regenerate the Xcode project after editing `project.yml` or adding/removing
files under `AppGym/` or `AppGymUITests/`:

```sh
xcodegen generate
```

Build the app:

```sh
xcodebuild -project AppGym.xcodeproj -scheme AppGym \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run the end-to-end UI test (core acceptance scenario):

```sh
xcodebuild test -project AppGym.xcodeproj -scheme AppGym \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:AppGymUITests/AppGymUITests/testCoreAcceptanceScenario
```

Install/run manually in the simulator:

```sh
xcrun simctl install <device-id> <path-to>/AppGym.app
xcrun simctl launch <device-id> com.ndelorte.appgym
```

## Notes for whoever (human or agent) touches this next

- `AppGym.xcodeproj` is generated — don't hand-edit it or add files to it
  directly in Xcode without also reflecting the change in `project.yml`, or
  the next `xcodegen generate` will drop them.
- If a Bash/xcodebuild/swift command fails with a sandbox-looking error
  (`sandbox_apply: Operation not permitted`, XPC "Connection invalid",
  `swiftpm-testing-helper ... unexpected signal code`), it's very likely the
  outer sandbox interfering with `simctl`/`swiftc`/toolchain subprocesses —
  re-run the same command outside the sandbox rather than debugging the
  toolchain.
- `ModelContext` does not retain its `ModelContainer`. Anything that builds a
  throwaway in-memory container (tests, previews) must keep a strong
  reference to the container itself for as long as the context is used, or
  you'll get a native crash (`EXC_BREAKPOINT`/`SIGTRAP`) the first time the
  context touches the store. See `AppGymKit/Tests/AppGymKitTests/TestSupport.swift`.
- The on-disk store lives at a fixed path (`AppGymSchema.defaultStoreURL`),
  not SwiftData's implicit default, specifically so the UI test can wipe it
  deterministically via the `-UITestReset` launch argument. Don't change
  that scheme without checking `AppGymUITests`.
