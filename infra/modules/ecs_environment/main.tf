locals {
  cluster_name = "${var.environment}-cluster"
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )
}
