# ADR-0032: User pool settings and invitations

- Status: Accepted
- Date: 2026-11-16
- Amends: [ADR-0004](0004-authentication-with-cognito.md) (how users are invited and the settings of the user pool and its app clients)

## Context

ADR-0004 decides one Cognito user pool per environment in the Essentials tier, two public app clients, SRP sign-in with our own screens, invite-only registration and optional TOTP MFA. F-20 creates the dev pool. Several pool settings cannot be changed after the pool exists, or would force a new pool, and a new pool gives every user a new `sub`. The `sub` is the owner ID of all data in DynamoDB ([DOMAIN](../DOMAIN.md), `userId`), so these settings are decided here.

Facts from the AWS documentation:

- The default Cognito email (sender `no-reply@verificationemail.com`) can send invitations and lets us customize the message, but it is limited to 50 emails per day for the whole account, and the limit cannot be raised ([email settings](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-email.html), [quotas](https://docs.aws.amazon.com/cognito/latest/developerguide/quotas.html)). A custom sender needs Amazon SES with a verified identity.
- `AdminCreateUser` sends the invitation by SMS unless `EMAIL` is requested, and `RESEND` sends a new temporary password. The temporary password is valid for 7 days by default. At the first sign-in the user must set a permanent password (`NEW_PASSWORD_REQUIRED` challenge) ([API reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminCreateUser.html), [creating users](https://docs.aws.amazon.com/cognito/latest/developerguide/how-to-create-user-accounts.html)).
- The Essentials tier is free up to 10,000 monthly active users, and this free tier does not end with the 12-month AWS Free Tier. A user created by an administrator counts as active in the month of creation ([pricing](https://aws.amazon.com/cognito/pricing/)).
- NIST SP 800-63B Rev. 4: a password used as the only factor must have at least 15 characters, verifiers must not impose composition rules, and they should allow at least 64 characters ([Password verifiers](https://pages.nist.gov/800-63-4/sp800-63b.html)). Cognito accepts a minimum length from 6 to 99 and passwords up to 256 characters ([password policy](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_PasswordPolicyType.html)).
- App client tokens default to one hour (access and ID) and 30 days (refresh) ([CreateUserPoolClient](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_CreateUserPoolClient.html)).

## Decision

**User pool** (`talktally-<env>-users`):

- **The email address is the username** (`UsernameAttributes = email`), case-insensitive. Users sign in with their email; there is no separate username. The pool verifies email automatically, and a changed email takes effect only after the user verifies it.
- **Deletion protection is active** in every environment, so neither Terraform nor the console can delete the pool and its users by mistake.
- **Only administrators create users** (`AllowAdminCreateUserOnly`). The invitation email is in English, like the UI ([VISION](../VISION.md)).
- **Password policy:** at least 15 characters, no composition rules; temporary passwords are valid for 7 days.
- **MFA is optional and uses TOTP only.** No SMS: it costs money per message and needs an SNS role.
- **Account recovery** only through the verified email.
- **Email is sent by Cognito's default email** for now. Before the public demo (F-63) or prod (F-65), whichever comes first, a sender on `talktally.tybu.me` through Amazon SES replaces it; that change needs its own issue.

**App clients** `web` (also desktop later) and `mobile`:

- Public clients without a secret. Only the SRP flow and refresh tokens are allowed (`ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`); no OAuth flows and no callback URLs, because there is no hosted login page (ADR-0004).
- `PreventUserExistenceErrors` is enabled, so sign-in and password recovery do not reveal whether an email has an account. Token revocation is enabled, so sign-out can revoke the refresh token.
- Access and ID tokens are valid for 60 minutes. Refresh tokens are valid for 30 days on `web` and 90 days on `mobile`, where the tokens live in secure storage and signing in again on a phone is more annoying. Refresh token rotation is decided in F-22, depending on what Amplify supports.

**Invitations:** the owner runs `pnpm invite <email>` with the administrator session ([ADR-0026](0026-admin-access-with-iam-user-and-aws-login.md)). The script calls `AdminCreateUser` through the AWS CLI with email delivery and marks the email as verified, because the invitation itself proves the address when the user signs in with the temporary password. `--resend` sends a new temporary password.

## Consequences

- At most 50 invitation, verification and password reset emails per day for all pools of the account. Enough while only invited people use the app; the SES sender removes the limit.
- The invitation comes from an AWS address, which may land in spam. Invited people are told to expect it.
- Deleting a pool needs a deliberate step: turn deletion protection off in one apply, then delete it in another.
- Clients must handle `NEW_PASSWORD_REQUIRED` at the first sign-in (F-22).
- Cost: nothing while the account has fewer than 10,000 active users per month.

## Alternatives considered

- **A separate username with email as an alias:** allows changing the sign-in name later, but adds a field nobody needs; email as the username is what users expect.
- **Amazon SES sender now:** a branded sender and no daily limit, but it needs DNS records, a verified identity and a request to leave the SES sandbox before it can email arbitrary addresses. Not needed for a handful of invitations.
- **Pre sign-up Lambda trigger with an allowlist in Parameter Store** (mentioned in ADR-0004): would allow self sign-up for listed emails, but needs a Lambda and our own sign-up screen. Admin-created users need neither.
- **Composition rules (Cognito's default of upper case, lower case, digits and symbols):** NIST advises against them; length protects better.
- **Deletion protection only in prod:** dev users and their data would be lost with the same ease, and the protection costs nothing.
