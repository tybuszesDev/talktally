# ADR-0028: Route 53 zone for the app subdomain

- Status: Accepted
- Date: 2026-11-14
- Amends: [ADR-0003](0003-terraform-infrastructure-as-code.md) (the domain is `tybu.me`; how the zone is protected) and [ADR-0027](0027-ci-access-to-aws-with-github-oidc-roles.md) (the shared denies cover the zone)

## Context

ADR-0003 delegates the app subdomain from Hostinger to a Route 53 hosted zone in the bootstrap stack, because the NS records at Hostinger must never change.

Facts that shape the details:

- **The domain is `tybu.me`, not `tybu.com`.** ADR-0003 and the other documents named the wrong domain. The owner's domain is `tybu.me`, registered at Hostinger, which also serves its DNS. `tybu.com` belongs to someone else. The decision in ADR-0003 does not change. Only the name is corrected there and in the other documents, so the app lives on `talktally.tybu.me`.
- **Name servers belong to the zone.** Route 53 assigns four name servers when it creates a public hosted zone. A new zone gets its own set, unless it uses a reusable delegation set ([CreateHostedZone](https://docs.aws.amazon.com/Route53/latest/APIReference/API_CreateHostedZone.html)). A deleted and recreated zone therefore needs new NS records at Hostinger.
- **The deploy role can change DNS.** `PowerUserAccess` allows every Route 53 action (ADR-0027). The environment stacks need some of them: they add certificate validation records and aliases for CloudFront and AppSync (F-23, F-65).
- **Record changes can be limited by type.** IAM policies can test `route53:ChangeResourceRecordSetsRecordTypes`, a multi-valued key with every record type in a `ChangeResourceRecordSets` request ([Route 53 condition keys](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/specifying-rrset-conditions.html)). `ForAnyValue:StringEquals` matches when at least one type in the request is in the list ([multi-valued context keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-single-vs-multi-valued-context-keys.html)).
- **DNSSEC would add nothing now.** `tybu.me` is not signed, so a signed subdomain has no chain of trust. Signing also needs a customer managed KMS key in `us-east-1` ([DNSSEC keys](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-cmk-requirements.html)), about 1 USD per month.

## Decision

**Zone.** The bootstrap stack creates the public hosted zone `talktally.tybu.me` with `prevent_destroy`. Its name servers are a bootstrap output. The owner adds them once at Hostinger, as four NS records named `talktally` in the `tybu.me` zone.

**Who owns which records.**

- The bootstrap stack owns the zone settings and the records at the zone apex: NS, SOA and the TXT record `v=spf1 -all`. The TXT record says that no mail is sent from `talktally.tybu.me`, so receivers reject mail that pretends to come from it. It is also the test record that proves the delegation from outside AWS.
- The environment stacks find the zone by name with the `aws_route53_zone` data source (ADR-0027) and manage their own records: `dev.`, `api.dev.`, `api.` and the apex alias of prod, and certificate validation records.

**Shared denies.** The deny statements that ADR-0027 applies to the deploy role and to the workload boundary get two more. So neither the deploy role nor any role it creates can:

- delete the zone, or change its DNSSEC settings and key-signing keys;
- create, change or delete NS or SOA records anywhere in the zone. The deny matches `ChangeResourceRecordSets` with `ForAnyValue:StringEquals` on `route53:ChangeResourceRecordSetsRecordTypes`, so a request that mixes NS or SOA with other types is denied too.

**Not enabled:** DNSSEC (see Context) and query logging.

## Consequences

- The NS records at Hostinger are set once. Only the owner can delete the zone: first remove `prevent_destroy` in a reviewed change, then apply locally. The new zone would then need new NS records at Hostinger.
- The environment stacks cannot delegate a further subdomain to a zone of its own. That would need a change in the bootstrap stack.
- The deploy role can still change the other records in the zone, including prod records from a dev job. This is the same gap as one deploy role for both environments (ADR-0027). If the role changes the apex TXT record, the next bootstrap apply restores it.
- The zone costs 0.50 USD per month, as planned in ADR-0002.
- The delegation depends on `tybu.me` staying registered. If the domain lapsed and someone else registered it, they could take over the app's host names. The owner keeps automatic renewal on at Hostinger ([ROADMAP owner actions](../ROADMAP.md#owner-actions)).

## Alternatives considered

- **A zone per environment** (a `dev.talktally.tybu.me` zone delegated from the main zone): separates dev and prod records, but adds 0.50 USD per month and NS records that the deploy role would have to manage. Reconsider with separate AWS accounts per environment.
- **A reusable delegation set:** a recreated zone would keep its name servers. It adds a resource for a case that `prevent_destroy` and the denies already prevent.
- **Route 53 record set protections** (`CreateResourceRecordSetProtections`): they reject changes to a protected name and type for everyone, the owner included ([API reference](https://docs.aws.amazon.com/Route53/latest/APIReference/API_CreateResourceRecordSetProtections.html)). The deploy role could delete a protection unless that is denied as well, so IAM denies alone are enough.
- **A temporary TXT record created with the CLI:** leaves nothing behind after the check, but the SPF record is useful on its own.
- **Moving all of `tybu.me` to Route 53:** one zone instead of two DNS providers, but the owner's other records would move too, and ADR-0003 chose delegation of the subdomain.
