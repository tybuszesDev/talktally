# Security policy

## Supported versions

TalkTally has no release yet. Security fixes go to `main`; after the first release, also to the latest release.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub: open the [Security tab](https://github.com/tybuszesDev/talktally/security) of this repository and choose **Report a vulnerability**. The report is visible only to the maintainer until a fix is published.

Please include:

- what is affected (component, URL or file) and the impact,
- steps to reproduce or a proof of concept,
- any suggested fix.

## What to expect

This is a one-person project, so responses are best effort:

- an acknowledgement within 7 days,
- an assessment and, for confirmed issues, a planned fix,
- credit in the published advisory, if you want it.

## Scope

- The code in this repository.
- The deployed app at `talktally.tybu.com` and its subdomains, once they exist. Do not access, modify or delete other users' data, and do not run load or denial-of-service tests.

The threat model and the controls in place are described in [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md).
