# ADR-0004: Authentication with Amazon Cognito

- Status: Accepted
- Date: 2026-11-05

## Context

The same user signs in on web, mobile and later desktop, and must see the same data everywhere. The API (AppSync) must know the caller's identity. The app is public on the internet, but every sign-up costs money through transcription and AI calls, so registration must be controlled. Electron makes redirect-based login flows harder (custom protocols, loopback servers).

## Decision

- **One Cognito user pool per environment** (Essentials tier; free up to 10,000 monthly active users).
- **Two public app clients without secrets:** `web` (also used by desktop later) and `mobile`. Separate clients allow different token lifetimes and callback URLs.
- **Sign-in with email and password through the SRP flow**, using our own UI screens. No redirect to a hosted page, so the same code works in the browser, in React Native and in Electron.
- **Client library:** AWS Amplify JS v6, only the `auth` and `api` categories. No Amplify CLI or Amplify Gen 2 backend; all resources come from Terraform. The apps receive pool IDs and endpoints as configuration generated from Terraform outputs.
- **Invite-only registration:** self sign-up is disabled. Users are created by the admin (CLI script) or through a Pre sign-up Lambda trigger that checks an allowlist in Parameter Store.
- **Demo account** for portfolio visitors with low quotas and periodic data reset.
- **Tokens:** AppSync uses the Cognito user pool authorization mode and reads `sub` as the owner ID. Tokens on mobile are stored in secure storage.
- **MFA:** optional TOTP.

## Consequences

- One identity across all clients; real-time subscriptions are authorized with the same token.
- Own login screens are more work than a hosted page, but they look consistent with the app and avoid redirect problems in Electron.
- Social login (Google, Apple) requires the managed login pages and redirect handling. That is post-MVP and needs a new ADR.

## Alternatives considered

- **Cognito managed login (hosted UI) with authorization code + PKCE:** needed for social providers; adds redirect handling on mobile (deep links) and desktop (custom protocol). Deferred.
- **Auth0, Clerk, Supabase Auth:** good developer experience, but outside AWS, and the goal is to use AWS services.
- **Own JWT authentication:** unnecessary security risk.
