# ADR-0014: Mobile distribution and device testing

- Status: Accepted
- Date: 2026-11-05

## Context

The mobile app ships on iOS first and on Android later. It must work on screens from the smallest to the largest iPhone. Simulators miss problems that only appear on real hardware: microphone permissions, audio recording quality, uploads in the background or on a weak network, safe areas and keyboards. The owner wants a professional tool for testing on many real devices and screen sizes, and has an Apple Developer Program membership.

## Decision

### Distribution

- **Apple Developer Program** (individual membership).
- **EAS Build** produces signed builds and manages certificates and provisioning profiles. **EAS Submit** uploads builds to **TestFlight**.
- Build profiles:
  - `development`: development client for local work.
  - `preview`: internal (ad hoc) build, used for device testing.
  - `production`: TestFlight and later the App Store.
- Separate bundle IDs per environment, so both apps can be installed side by side: `com.tybu.talktally.dev` and `com.tybu.talktally`.
- If the EAS free build quota is not enough, builds run with `eas build --local` on GitHub-hosted macOS runners, which are free for public repositories.
- **Android after the MVP:** Google Play Console (one-time 25 USD fee), internal testing track, same EAS pipeline.

### Device testing

- **Framework:** Appium 2 with WebdriverIO, in TypeScript, in `apps/mobile/e2e`. Tests select elements only by `testID` (accessibility identifier), so the same tests run on iOS and Android.
- **Scope:** a small set of critical flows: sign in, view today's plan, record and upload a dictation, review a pending operation, undo.
- **Simulators:** the same tests run on iOS simulators (smallest, standard and largest current iPhone) on GitHub macOS runners, nightly and on manual dispatch. Not on every pull request, because they are slow.
- **Real devices: AWS Device Farm** (region `us-west-2`, the only region where it exists).
  - Device pool `ios-core`: one small, one standard and one large iPhone, one iPad, on the current and the previous major iOS version.
  - Device pool `android-core` (after the MVP): small and large Pixel, one Samsung Galaxy.
  - Runs on release candidates (tags) and on manual dispatch. The `preview` build and the test package are uploaded, and the run's videos, logs and screenshots are linked in the GitHub job summary. A failed run blocks the release.
  - Remote access sessions are used for manual exploratory testing on devices the owner does not have.
- **Backend for device tests:** the dev environment with a dedicated test user created by a script. Test data is reset before each run.

### Cost

AWS Device Farm gives a one-time trial of 1,000 device minutes, then charges 0.17 USD per device minute. A run on 4 devices of about 8 minutes each uses about 32 device minutes, so the trial covers about 30 release runs. After that one run costs about 5.40 USD, which is why runs happen only for releases.

## Consequences

- Every release is verified on real iPhones of different sizes, with video evidence.
- Feedback from device tests is slow, so unit and component tests (ADR-0011) stay the main safety net.
- Appium tests are slower and can be flakier than gray-box tools. This is reduced with stable `testID`s, explicit waits and a small number of critical flows.
- `us-west-2` becomes the second exception to the single-region rule (ADR-0002). CI gets a separate IAM role with Device Farm permissions only.

## Alternatives considered

- **Maestro:** very good developer experience with simple YAML flows, but AWS Device Farm does not support it natively, and Maestro Cloud is a paid service. It may be added later for fast local checks.
- **Detox:** fast gray-box tests for React Native, but only on simulators and emulators, not on device clouds.
- **BrowserStack App Automate or Sauce Labs:** larger device coverage and polished dashboards, but paid monthly plans and outside AWS. A fallback if Device Farm is not enough.
- **Firebase Test Lab:** good for Android, limited for iOS, and outside AWS.
- **Native XCUITest:** fast and stable on iOS, but written in Swift and cannot be reused for Android.
