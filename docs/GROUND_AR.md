# Ground AR

Ground provides two ways to plan a cricket pitch:

- **Top-view planner:** a Flutter diagram with drag/move, zoom, rotation, fine adjustments, undo/redo, locking and saved layout preferences. It works without camera permission and remains available when AR is unsupported.
- **Ground AR:** an optional native Android screen using an ARCore `Session`, camera texture, detected horizontal planes and independent local anchors at the two ends. Stumps, bails and ground markings are rendered as 3D geometry. The top-view planner is not a camera overlay or a substitute for AR tracking.

This feature does not change scoring, account authentication, match sync or Firestore rules. Earlier project-review findings remain outside this feature's implementation scope.

## Using the planner

Open **Ground**, then choose **22 yards** or a custom pitch length. The planner's custom entry uses yards and validates the converted value against **4–40 metres**. Native AR settings accept metres. Stump and crease dimensions keep their standard sizes when pitch length changes.

| Setting | Default | Supported range |
| --- | --- | --- |
| Pitch length | 22 yd / 20.1168 m | 4–40 m |
| Stumps and bails | On | On/off |
| Crease markings | On | On/off |
| Custom wide guides | Off | On/off |
| Wide-guide offset from centre | 0.9 m | 0.3–1.3 m |
| Bowling-end run-up marker | Off / 0 m | 0–20 m |

Custom wide guides are practice aids. They do not determine whether a delivery is a Wide. The planner can swap the diagram's batting/bowling ends; an AR session establishes its own endpoints from the placement steps below.

Use **Save** to retain the diagram and preferences locally. Returning normally from native AR applies its layout preferences and saves them through the Flutter page. Diagram position and orientation are not physical-world coordinates.

## Placing a real ground in AR

1. Open AR from Ground. Allow camera access and complete the Google Play Services for AR installation/update prompt if shown.
2. Move the phone slowly over a well-lit, textured, roughly level surface. A translucent grid and boundary show the actual detected surface. A blank or shiny floor may need a different viewing angle or a more textured area. Empty space is never treated as detected ground.
3. Aim the centre marker at the surface and hold it steady until placement becomes available, then use **Place batting end**. The phone must be within 5 m of the hit. Scanning and a real local anchor are required; the app does not guess floor height from the camera.
4. Tap another detected ground point at least 1 m ahead to choose direction. This point sets direction, not the pitch length.
5. Walk to the expected bowling-end marker. Scan ground around it, then tap nearby ground or use **Confirm bowling end**. Confirmation requires a nearby detected surface containing the expected endpoint, a ground hit within 1.5 m of the target, and the phone within 5 m of the hit. Until confirmation, this end is an aim marker rather than an anchored wicket.
6. Inspect both ends, use **Move** or open **Adjust** for **2° rotation** and **5 cm ground nudges**, then **Lock**. Lock prevents accidental edits; it does not improve sensor accuracy. A larger relocation or length adjustment can require confirming the bowling end again.
7. Use **Save** or system Back to return. **More** contains **Undo**, **Redo**, **Remove** and **Reset**. Undo restores earlier edits in the current session. Remove clears placement; Reset returns to the default pitch and clears placement, with an in-session undo available.

Keep the walking route clear and look up while moving between ends. Camera permission, installation or tracking failures offer a route back to the planner.

## Tracking and measurement limits

The configured 22-yard geometry is **20.1168 m**. The physical location of that geometry is an AR estimate. Camera movement, texture, lighting, plane estimation and drift affect the result. Use a tape to verify the distance between middle stumps/bowling creases and the position of the other markings before painting or playing.

The AR status reports the **tracked horizontal endpoint spacing** alongside the **configured target**. It flags endpoint alignment shifts exceeding **0.15 m** or heading divergence exceeding **3°**. These are feedback thresholds, not an accuracy guarantee or an acceptance tolerance for a marked pitch. The app does not continuously move the anchors to conceal drift.

Each wicket and its nearby creases use their own anchor. The route between them and any run-up markers are visual guides. Long-distance tracking still needs physical testing. Google notes that independently anchored objects may shift relative to each other as the world estimate changes; see [Working with Anchors](https://developers.google.com/ar/develop/anchors).

Tracking pauses produce visible guidance; untracked endpoint geometry is hidden and fine edits are blocked until tracking recovers. This implementation uses horizontal plane hit tests and ambient lighting. It does not enable depth occlusion, Cloud Anchors, Geospatial anchors or persistent maps. Real objects can therefore appear behind rendered virtual objects even when they are physically in front.

The scan overlay draws only tracked upward-facing plane polygons, not raw point-cloud dots. The grid is a surface-detection aid, not a measurement ruler. It is hidden when the layout is locked. The amber bowling-end target is an estimate calculated from the current batting anchor every frame; it becomes a wicket only after local ground confirmation. Neither endpoint is saved as a fixed world-coordinate pose across frames.

### September 18 video review

The supplied 44-second recording shows placement being accepted before a visible ground target, an empty camera view immediately afterward, wickets appearing off to the side later, and insufficient-feature tracking pauses on a glossy floor. Reviewing the current `c51a38b` source identified an unanchored, guessed-height placement path pointing along the camera's backward axis, plus a cached unanchored bowling endpoint. The correction requires scanned ground, uses the camera's forward direction, and restores local anchors at both ends. The recording documents the prior behavior; it does not validate the corrected build's physical stability.

## Device support and privacy

The Android app requires API 24 or newer. AR additionally requires a compatible device, working camera, camera permission and a compatible Google Play Services for AR installation. Consult Google's current [supported-device list](https://developers.google.com/ar/devices); being an Android phone alone does not establish AR support.

The plugin declares AR, camera, autofocus and OpenGL features as optional. The app can provide its planner/scoring flows without AR support. Availability states are `supported`, `installRequired`, `unsupported` and `checking`. A failed or unfinished capability check offers retry; it does not present a simulated camera view.

Ground preferences use the separate device-local `cricxii_ground_setup_v1` SharedPreferences key. They are not synchronized through Firestore. The native bridge returns only versioned layout settings; world poses, anchors and camera frames are not written to that saved layout. Undo anchors live only while the native activity/session exists. Closing AR, recreating the activity or restarting the app requires a new ground scan. Clearing app data removes the saved layout.

Ground AR uses **Google Play Services for AR**, supplied by Google and governed by the [Google Privacy Policy](https://policies.google.com/privacy). The Ground screen includes an accessible disclosure/link. Google's [ARCore privacy requirements](https://developers.google.com/ar/develop/privacy-requirements) describe this disclosure. The feature does not record or export the live camera feed, and it does not host Cloud Anchors or call Geospatial APIs.

## Build and implementation

The durable native source is the local Flutter plugin at `packages/cricxii_ground_ar`. Its manifest, Kotlin activity, renderer and dependencies are kept outside the generated `android/` shell so bootstrap regeneration preserves the feature.

| Component | Implementation |
| --- | --- |
| Flutter page | `lib/screens/ground_setup_page.dart` |
| Diagram | `lib/widgets/ground_preview.dart` |
| Geometry/preferences | `lib/domain/ground_layout.dart`, `lib/services/ground_setup_controller.dart` |
| Flutter-native gateway | `lib/services/ground_ar_service.dart` |
| Channel | `com.texiol.crixx/ground_ar` |
| Native activity | `GroundArActivity.kt` in the plugin |
| Renderer | Plugin `rendering/` package, OpenGL ES and original procedural geometry |
| AR dependency | `com.google.ar:core:1.54.0`; no Sceneform |
| Android plugin build | compileSdk 36, minSdk 24, Java 17, AGP 8.11.1, Kotlin 2.2.20 |

Use the repository's Flutter SDK/CI configuration, JDK 17 and an installed Android SDK with platform 36. The host application keeps an explicit target SDK. The ARCore dependency is pinned to the [official 1.54.0 SDK release](https://github.com/google-ar/arcore-android-sdk/releases/tag/1.54.0); upgrading it should include native compile, manifest and physical-device regression checks.

From the repository root in Bash:

```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Run the plugin's JVM tests from the generated Android directory:

```bash
./gradlew :cricxii_ground_ar:testDebugUnitTest
```

On Windows use `gradlew.bat` from `android`. Native unit tests cover input sanitization, settings-only serialization, pitch geometry, headings, nudges and drift calculations. They do not exercise a camera, sensors, plane detection, real shaders or AR installation.

Session lifecycle follows [Google's Session API](https://developers.google.com/ar/reference/java/com/google/ar/core/Session): resume the session before rendering, pause rendering before the session, and close the stopped session on a background thread. API 33+ uses `OnBackInvokedCallback`; older devices use the legacy Back callback. This also covers [Android 16's changed Back behavior](https://developer.android.com/about/versions/16/behavior-changes-16).

## Validation status and device matrix

**Validation on September 18, 2026:** all 82 Flutter tests and all 21 native JVM tests passed. Native debug compilation and full debug APK packaging passed. The Ground page tests and screenshot harness also passed after the final contrast adjustment. Flutter analysis completed with only the pre-existing `prefer_initializing_formals` info at `lib/domain/team_match.dart:98`. The supplied recording was reviewed to diagnose the previous build; no connected physical AR phone was available to validate the corrected build's tracking or graphics.

| Check | Required evidence | Current status |
| --- | --- | --- |
| Flutter analysis and tests | `flutter analyze --no-pub --no-fatal-infos`; `flutter test --no-pub --reporter expanded` | Passed: 82 tests; one existing style info |
| Native compile and JVM tests | `:cricxii_ground_ar:testDebugUnitTest` | Passed: debug Kotlin compilation; 21 tests, zero failures/errors |
| APK packaging | `flutter build apk --debug --no-pub --dart-define=FIREBASE_ENABLED=false` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| Supported physical phone | Device model, Android version, AR service version; real camera, both placements and tracking | Not run; phone unavailable |
| Unsupported Android phone | Planner remains usable, AR unavailable message, no crash/permission loop | Not run |
| AR service missing/outdated | Install/update success and cancellation return to planner | Not run |
| Camera permission | Grant, deny, permanent denial, settings recovery and camera already in use | Not run |
| Standard 22-yard ground | Tape-measured 20.1168 m between middle-stump positions; verify crease distances at both ends | Not run |
| Ground conditions | Textured soil/grass/concrete, low light, blank ground, slopes, fast movement | Not run |
| Anchor stability | Walk between ends, inspect from different angles, pause/recover tracking, record actual observed drift | Not run |
| Editing | Move/rotate/nudge/length/toggles/lock/undo/remove/reset; toggles must not shift anchors | Not run on hardware |
| Lifecycle and saving | Background/resume, rapid Apply→Save, system Back on old/new Android, reopen/restart requiring scan | Not run on hardware |

Minimum physical acceptance requires **one supported AR phone, one unsupported Android device, and a tape-measured 22-yard placement**. Record measured deviations instead of assuming that matching the configured value proves physical accuracy. Hardware results determine whether any additional device restrictions or tracking refinements are needed.

The local debug APK is an **AR test build without Firebase configuration**. From the sign-in screen choose **Set up a ground · no sign-in needed**. It is not a production account/sync build. Initial packaging attempts hit dependency-host DNS and connection failures; the final local build used copies of the missing Flutter/Firebase artifacts downloaded from their official repositories and verified against official content hashes/checksums. This cache and its generated Android-shell configuration are local only; the versioned CI dependency declarations remain unchanged. Kotlin incremental compilation was disabled in the generated Windows shell to avoid its cross-drive cache error between the C: Pub cache and D: checkout.
