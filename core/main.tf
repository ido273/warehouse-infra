# Permanent infrastructure: Route53 hosted zone + ACM certificate.
#
# Lives in its own state (see backend.tf) specifically so it survives a
# `terraform destroy` of the main stack (root main.tf / modules/eks etc).
# Destroying and recreating a hosted zone changes its nameservers, which
# would require re-delegating the domain at the registrar every time the
# cluster is torn down and rebuilt — this layer exists to avoid that.
#
# modules/dns reads these back via data sources (aws_route53_zone,
# aws_acm_certificate looked up by domain_name), it no longer creates them.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
