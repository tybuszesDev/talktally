# Public hosted zone of the app subdomain, delegated from the tybu.me zone at
# Hostinger (ADR-0003, ADR-0028). This stack owns the zone and its apex
# records. envs/dev and envs/prod find the zone by name and add their own
# records.

locals {
  app_domain = "talktally.tybu.me"
}

resource "aws_route53_zone" "app" {
  name    = local.app_domain
  comment = "TalkTally app subdomain, delegated from Hostinger (ADR-0028)."

  # A new zone gets new name servers, so the NS records at Hostinger would have
  # to change.
  lifecycle {
    prevent_destroy = true
  }
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
