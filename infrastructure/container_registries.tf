resource "aws_ecr_repository" "badgery_api" {
  name                 = "badgery_api_aws_ecr_repository"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}