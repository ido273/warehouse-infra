output "jwt_secret" {
  description = "Generated JWT signing secret. Seed into the \"warehouse/app-secrets\" AWS Secrets Manager secret as \"jwt-secret\" (ESO reads it from there)."
  value       = random_password.jwt.result
  sensitive   = true
}

output "flask_secret" {
  description = "Generated Flask session secret. Seed into the \"warehouse/app-secrets\" AWS Secrets Manager secret as \"flask-secret\" (used for both the backend and frontend's SECRET_KEY)."
  value       = random_password.flask.result
  sensitive   = true
}
