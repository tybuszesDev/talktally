# ADR-0028: Route 53 zones for tybu.me and the app subdomain

- Status: Accepted
- Date: 2026-11-15
- Amends: [ADR-0002](0002-serverless-aws-and-cost-guardrails.md) (two hosted zones), [ADR-0003](0003-terraform-infrastructure-as-code.md) (the domain is `tybu.me`; Route 53 serves the whole domain) and [ADR-0027](0027-ci-access-to-aws-with-github-oidc-roles.md) (the shared denies cover the zones)

## Context

ADR-0003 delegates the app subdomain from the Hostinger DNS zone editor to a Route 53 hosted zone in the bootstrap stack, because the delegation must never change.

Facts that shape the details:

- **The domain is `tybu.me`, not `tybu.com`.** ADR-0003 and the other documents named the wrong domain. The owner's domain is `tybu.me`, registered at Hostinger. `tybu.com` belongs to someone else. The app lives on `talktally.tybu.me`.
- **Hostinger cannot delegate a subdomain.** "Hostinger domains don't allow custom nameservers (NS records) for subdomains – only for the main domain" ([Hostinger: DNS records](https://www.hostinger.com/support/1583249-how-to-manage-dns-records-at-hostinger/)). The domain itself can use up to four custom name servers ([Hostinger: change nameservers](https://www.hostinger.com/support/1696789-how-to-change-nameservers-at-hostinger/)). Today Hostinger serves only its parking page for `tybu.me`.
- **Name servers belong to the zone.** Route 53 assigns four name servers when it creates a public hosted zone. A new zone gets its own set, unless it uses a reusable delegation set ([CreateHostedZone](https://docs.aws.amazon.com/Route53/latest/APIReference/API_CreateHostedZone.html)). A deleted and recreated zone therefore breaks every delegation to it.
- **Delegation inside Route 53.** A subdomain zone is delegated by an NS record in the parent zone with the subdomain zone's name servers ([routing traffic for subdomains](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-routing-traffic-for-subdomains.html)).
- **The deploy role can change DNS.** `PowerUserAccess` allows every Route 53 action (ADR-0027). The environment stacks need some of them: they add certificate validation records and aliases for CloudFront and AppSync (F-23, F-65).
- **Record changes can be limited by type.** IAM policies can test `route53:ChangeResourceRecordSetsRecordTypes`, a multi-valued key with every record type in a `ChangeResourceRecordSets` request ([Route 53 condition keys](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/specifying-rrset-conditions.html)). `ForAnyValue:StringEquals` matches when at least one type in the request is in the list ([multi-valued context keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-single-vs-multi-valued-context-keys.html)).
- **DNSSEC would add nothing now.** `tybu.me` is not signed at the registry, so no chain of trust reaches the zones. Signing also needs a customer managed KMS key in `us-east-1` ([DNSSEC keys](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-cmk-requirements.html)), about 1 USD per month.

## Decision

**Route 53 serves all of `tybu.me`.** Hostinger stays the registrar. Its name servers for `tybu.me` are the four name servers of a Route 53 zone `tybu.me`. The owner sets them once in hPanel.

**Two zones in the bootstrap stack**, both with `prevent_destroy`:

- `tybu.me` holds only the NS record that delegates `talktally.tybu.me` to the app zone. The Hostinger parking records are not copied. Records that the owner later wants for other uses of `tybu.me` are added here.
- `talktally.tybu.me` is the app zone. The bootstrap stack owns its settings and apex records: NS, SOA and the TXT record `v=spf1 -all`. The TXT record says that no mail is sent from `talktally.tybu.me`, so receivers reject mail that pretends to come from it. It is also the test record that proves the delegation from outside AWS.

The environment stacks find the app zone by name with the `aws_route53_zone` data source (ADR-0027) and manage their own records in it: `dev.`, `api.dev.`, `api.`, the apex alias of prod, and certificate validation records.

**Shared denies.** The deny statements that ADR-0027 applies to the deploy role and to the workload boundary get three more. So neither the deploy role nor any role it creates can:

- use the `tybu.me` zone at all (`route53:*` on its ARN);
- delete the app zone, or change its DNSSEC settings and key-signing keys;
- create, change or delete NS or SOA records anywhere in the app zone. The deny matches `ChangeResourceRecordSets` with `ForAnyValue:StringEquals` on `route53:ChangeResourceRecordSetsRecordTypes`, so a request that mixes NS or SOA with other types is denied too.

**Not enabled:** DNSSEC (see Context) and query logging.

## Consequences

- DNS costs 1.00 USD per month for two zones instead of the 0.50 USD planned in ADR-0002. The total stays well within the 10 USD budget.
- The Hostinger DNS zone editor no longer applies to `tybu.me`. Every record of the domain, including any later use outside TalkTally, is managed in this stack and applied locally by the owner.
- The name servers at Hostinger and the delegation are set once. Only the owner can delete a zone: first remove `prevent_destroy` in a reviewed change, then apply locally. A new `tybu.me` zone would need new name servers at Hostinger.
- The environment stacks cannot delegate a further subdomain to a zone of their own. That would need a change in the bootstrap stack.
- The deploy role can still change the other records in the app zone, including prod records from a dev job. This is the same gap as one deploy role for both environments (ADR-0027). If the role changes the apex TXT record, the next bootstrap apply restores it.
- The delegation depends on `tybu.me` staying registered. If the domain lapsed and someone else registered it, they could take over the app's host names. The owner keeps automatic renewal on at Hostinger ([ROADMAP owner actions](../ROADMAP.md#owner-actions)).

## Alternatives considered

- **NS records for the subdomain in the Hostinger DNS zone editor:** the plan in ADR-0003. Hostinger does not allow them.
- **One Route 53 zone for `tybu.me` with the app records in it:** saves 0.50 USD per month. The deploy role would then write to a zone that also holds the owner's other records. Keeping it to app names needs deny conditions on record names, which are easy to get wrong.
- **App records in the Hostinger DNS zone editor, no Route 53:** no DNS cost. Every certificate validation and alias record would be added by hand, or CI would need a Hostinger API token for the owner's whole account. ADR-0003 wants Terraform to manage all records.
- **Another DNS provider for `tybu.me` that can delegate a subdomain:** no AWS cost, but a third provider with its own account to secure.
- **A zone per environment** (a `dev.talktally.tybu.me` zone delegated from the app zone): separates dev and prod records, but adds 0.50 USD per month and NS records that the deploy role would have to manage. Reconsider with separate AWS accounts per environment.
- **A reusable delegation set:** a recreated zone would keep its name servers. It adds a resource for a case that `prevent_destroy` and the denies already prevent.
- **Route 53 record set protections** (`CreateResourceRecordSetProtections`): they reject changes to a protected name and type for everyone, the owner included ([API reference](https://docs.aws.amazon.com/Route53/latest/APIReference/API_CreateResourceRecordSetProtections.html)). The deploy role could delete a protection unless that is denied as well, so IAM denies alone are enough.
- **A temporary TXT record created with the CLI:** leaves nothing behind after the check, but the SPF record is useful on its own.
