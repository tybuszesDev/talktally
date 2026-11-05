# ADR-0010: Client applications: Vite SPA, Expo, Electron later

- Status: Accepted
- Date: 2026-11-05

## Context

Three clients share one backend: a rich web app, a thin mobile capture app and, later, a desktop app built by wrapping the web app in Electron. Logic must be shared; UI components cannot be shared between React DOM and React Native without heavy abstraction. The UI is English for the MVP; Polish comes later.

## Decision

### Web (`apps/web`)

- **Vite + React + TypeScript**, built as a static **single-page application**.
- **TanStack Router** (type-safe routes) and **TanStack Query** (server state).
- **Tailwind CSS** with **shadcn/ui** (Radix primitives) for components.
- Hosted on **S3 + CloudFront** with Origin Access Control; SPA fallback to `index.html`.

### Electron readiness rules for the web app

- No server-side rendering and no server-only APIs.
- The router history is configurable: browser history on the web, hash history in Electron (`file://` has no server for deep links).
- Runtime configuration (API endpoint, Cognito IDs) is read from one config module, never from `window.location`.
- Authentication uses the SRP flow without redirects (ADR-0004), so it works unchanged inside Electron.
- Browser-only features (media recording, notifications) are wrapped behind small interfaces that Electron can implement differently.

### Mobile (`apps/mobile`)

- **Expo** (React Native) with **Expo Router**, run as a development build (Amplify needs native modules, so Expo Go is not enough).
- **iOS first.** The MVP is released through TestFlight and tested on iOS. The code stays cross-platform; the Android release follows after the MVP (ADR-0014).
- Every interactive element has a stable `testID` (accessibility identifier) for end-to-end tests.
- **expo-audio** for recording; a local queue for offline recordings.
- Tokens in secure storage.
- Screens only for the core loop: sign-in, today's plan, dictation, entry status, review of pending operations, project switch.

### Desktop (`apps/desktop`, post-MVP)

- Electron loads the built web app. Extras such as a tray icon or a global dictation shortcut are decided in a later ADR.

### Shared code

- `packages/client`: Amplify configuration, auth hooks, GraphQL operations, TanStack Query hooks, subscription-to-cache sync. No DOM or React Native imports.
- `packages/domain`: types, validation and formatting helpers.
- No shared UI component library between web and mobile: share logic, not views.

### Language

- UI strings in English. No i18n framework in the MVP, but strings live in components or small constant modules, not inside business logic, so they can be extracted later.
- Dictation language (Polish) is a user setting, independent from the UI language.

## Consequences

- The web app can be wrapped in Electron later with little change.
- Mobile requires development builds, which means local native toolchains (Xcode, Android Studio) or EAS Build.
- Some UI is written twice (web and mobile). Accepted, because the mobile app is deliberately small.

## Alternatives considered

- **Next.js:** strong framework, but server rendering and server actions complicate both static hosting and the Electron wrapper.
- **React Native for Web / Expo for all platforms:** one UI codebase, but a weaker fit for a data-dense desktop dashboard.
- **Bare React Native without Expo:** more control, more maintenance; Expo covers everything this app needs.
- **Tauri instead of Electron:** smaller binaries, but the owner asked for Electron and Tauri's webview differs per OS.
