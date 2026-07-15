output "name_servers" {
  description = "Add these to GoDaddy nameservers"
  value       = data.aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = data.aws_acm_certificate.main.arn
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}