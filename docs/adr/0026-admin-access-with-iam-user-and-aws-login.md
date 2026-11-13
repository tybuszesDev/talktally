# ADR-0026: Administrator access with an IAM user and `aws login`

- Status: Accepted
- Date: 2026-11-13

## Context

The owner needs daily administrator access to the AWS account: the console, and the AWS CLI and Terraform for the bootstrap stack (ADR-0003). The root user must not be used for daily work. CI never uses this access; it assumes roles through OIDC (ADR-0003, F-11).

The roadmap planned an administrator user in IAM Identity Center. Identity Center can give a user access to an AWS account only through an organization instance, and enabling one in a standalone account creates an AWS Organizations organization ([IAM Identity Center instances](https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-instances.html), [Enable IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/get-set-up-for-idc.html)).

The account is on the AWS Free Tier free plan with about 100 USD of credits. ADR-0002 counts on these credits.

- An account that joins AWS Organizations is upgraded to the paid plan automatically ([Free Tier plans](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)).
- The Free Tier terms add: "If you are using an AWS Free Plan account and enroll in AWS Organizations, your account will be upgraded to a Paid Plan account, and you will no longer be able to use or earn credits offered under the Free Tier" ([AWS Free Tier Terms](https://aws.amazon.com/free/terms/)).
- A manual upgrade from the Billing console keeps the remaining credits: "your remaining Free Tier credits will automatically apply to future AWS bills until they expire" ([Free Tier FAQs](https://aws.amazon.com/free/free-tier-faqs/)).
- The free plan ends six months after the account was created, or when the credits are used up. After that the account closes ([Free Tier plans](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)).

Since AWS CLI 2.32.0, `aws login` signs the CLI in with console credentials. These include IAM users with a password and MFA. It needs no access keys and no IAM Identity Center ([Login for AWS local development](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html)).

## Decision

- Daily administrator access uses an **IAM user** with a console password and a **passkey or security key as MFA**. The user has the AWS managed policies `AdministratorAccess` and `SignInLocalDevelopmentAccess` (the second allows `aws login`).
- The AWS CLI and Terraform sign in with `aws login --profile talktally-admin` and get temporary credentials. The CLI refreshes them for up to 12 hours. **No access keys exist**, for the IAM user or for the root user.
- The root user has MFA and is used only for account and billing tasks.
- **IAM Identity Center and AWS Organizations are not enabled while the account is on the free plan**, so the Free Tier credits are not lost.
- Before the free plan ends, the owner upgrades the account to the paid plan by hand (Billing console, "Upgrade plan").
- Terraform code never sets a `profile`. Locally the profile comes from `AWS_PROFILE`; CI uses OIDC roles.

## Consequences

- The credits stay available, and the account needs no organization.
- An IAM user has a long-lived password. Passkey MFA and the absence of access keys limit the risk.
- One person, one account: there is no central place to manage several users. Inviting more administrators would need more IAM users.
- Tools must support console credentials (`login_session` in the shared config file). The AWS SDK for Go v2 supports them from `config` v1.32.0, which the Terraform AWS provider and the S3 backend in use already include. Older tools can use a `credential_process` profile that calls `aws configure export-credentials`, as the AWS CLI guide describes.
- Moving to IAM Identity Center later is possible once the credits are used up or have expired. That change needs a new ADR.

## Alternatives considered

- **IAM Identity Center with AWS Organizations (the original plan):** AWS's recommended access model, but it upgrades the account to the paid plan, and under the Free Tier terms the credits stop being usable.
- **IAM Identity Center account instance:** needs no organization, but it cannot give users access to AWS accounts.
- **IAM user with access keys:** works with every tool, but leaves long-lived secrets on disk, which ADR-0003 rules out.
- **Root user with `aws login`:** needs no IAM user, but the root user has unlimited power and should not be used for daily work.
