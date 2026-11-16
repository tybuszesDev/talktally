# Configuration of the apps (ADR-0004): F-22, F-23 and F-24 read these. The IDs
# are not secret; they ship in every app bundle.
output "user_pool_id" {
  description = "ID of the Cognito user pool."
  value       = aws_cognito_user_pool.users.id
}

output "web_client_id" {
  description = "ID of the Cognito app client for the web app (and later the desktop app)."
  value       = aws_cognito_user_pool_client.app["web"].id
}

output "mobile_client_id" {
  description = "ID of the Cognito app client for the mobile app."
  value       = aws_cognito_user_pool_client.app["mobile"].id
}
