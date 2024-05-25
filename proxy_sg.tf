module "rds_proxy_sg_region_1" {
  source  = "./modules/rds_proxy_sg_region_1"

  name        = "${local.name}-proxy"
  description = "PostgreSQL RDS Proxy example security group"
  vpc_id      = module.vpc.vpc_id

  revoke_rules_on_delete = true

  ingress_with_cidr_blocks = [
    {
      description = "Private subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    }
  ]

  egress_with_cidr_blocks = [
    {
      description = "Database subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc.database_subnets_cidr_blocks)
    },
  ]

  tags = local.tags
}


module "rds_proxy_sg_region_2" {
  source  = "./modules/rds_proxy_sg_region_2"

  providers = {
    aws = aws.region2
  }

  name        = "${local.name}-proxy"
  description = "PostgreSQL RDS Proxy example security group"
  vpc_id      = module.vpc_secondary.vpc_id

  revoke_rules_on_delete = true

  ingress_with_cidr_blocks = [
    {
      description = "Private subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc_secondary.private_subnets_cidr_blocks)
    }
  ]

  egress_with_cidr_blocks = [
    {
      description = "Database subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc_secondary.database_subnets_cidr_blocks)
    },
  ]

  tags = local.tags
}