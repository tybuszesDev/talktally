# DNS of the app (ADR-0003, ADR-0028). Hostinger stays the registrar of
# tybu.me but cannot delegate a subdomain, so Route 53 serves the whole domain:
# the tybu.me zone only delegates talktally.tybu.me to the app zone. This stack
# owns both zones and their apex records. envs/dev and envs/prod find the app
# zone by name and add their own records to it.

locals {
  parent_domain = "tybu.me"
  app_domain    = "talktally.${local.parent_domain}"
}

# Hostinger lists this zone's name servers as the name servers of tybu.me.
resource "aws_route53_zone" "parent" {
  name    = local.parent_domain
  comment = "tybu.me, served by Route 53 for the TalkTally delegation (ADR-0028)."

  # A new zone gets new name servers, so the name servers at Hostinger would
  # have to change.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "app" {
  name    = local.app_domain
  comment = "TalkTally app subdomain, delegated from the tybu.me zone (ADR-0028)."

  # A new zone gets new name servers, so the delegation would have to change.
  lifecycle {
    prevent_destroy = true
  }
}

# Delegates talktally.tybu.me to the app zone. Two days is the TTL that
# Route 53 recommends for NS records; the name servers never change.
resource "aws_route53_record" "app_delegation" {
  zone_id = aws_route53_zone.parent.zone_id
  name    = local.app_domain
  type    = "NS"
  ttl     = 172800
  records = aws_route53_zone.app.name_servers
}

# talktally.tybu.me sends no mail, so receivers reject mail that claims to come
# from it. It is also the record that proves the delegation from outside AWS.
resource "aws_route53_record" "app_spf" {
  zone_id = aws_route53_zone.app.zone_id
  name    = local.app_domain
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 -all"]
}
