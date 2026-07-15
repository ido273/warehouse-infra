data "aws_elb_hosted_zone_id" "main" {}

# Zone and certificate are permanent infrastructure now owned by ../../core
# (its own state, survives `terraform destroy` of this stack). Read them
# back by domain name instead of creating them here.
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

data "aws_acm_certificate" "main" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# The A-record aliasing the domain to the ingress NLB is stack-specific (the
# NLB is recreated every apply) and still lives here, not in core/ — it still
# needs nlb_hostname.
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.nlb_hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}