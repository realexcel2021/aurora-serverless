################################################################################
# RDS Proxy
################################################################################

module "rds_proxy_region_1" {
  source = "./modules/rds_proxy_region_1"

  name                   = "${local.name}-proxy"
  iam_role_name          = local.name
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [module.rds_proxy_sg_region_1.security_group_id]

  endpoints = {
    read_write = {
      name                   = "read-write-endpoint"
      vpc_subnet_ids         = module.vpc.private_subnets
      vpc_security_group_ids = [module.rds_proxy_sg_region_1.security_group_id]
      tags                   = local.tags
    }
  }

  auth = {
    "root" = {
      description = "Cluster generated master user password"
      secret_arn  = aws_secretsmanager_secret.db_pass.arn
    }
  }

  engine_family = "POSTGRESQL"
  debug_logging = true

  # Target Aurora cluster
  target_db_cluster     = true
  db_cluster_identifier = module.aurora_postgresql_v2_primary.cluster_id

  tags = local.tags
}


module "rds_proxy_region_2" {
  source = "./modules/rds_proxy_region_2"

  providers = {
    aws = aws.region2
  }

  name                   = "${local.name}-proxy-${local.region2}"
  iam_role_name          = "${local.name}-proxy-${local.region2}"
  vpc_subnet_ids         = module.vpc_secondary.private_subnets
  vpc_security_group_ids = [module.rds_proxy_sg_region_2.security_group_id]

  endpoints = {
    read_write = {
      name                   = "read-write-endpoint"
      vpc_subnet_ids         = module.vpc_secondary.private_subnets
      vpc_security_group_ids = [module.rds_proxy_sg_region_2.security_group_id]
      tags                   = local.tags
    }
  }

  auth = {
    "root" = {
      description = "Cluster generated master user password"
      secret_arn  = replace(aws_secretsmanager_secret.db_pass.arn, local.region, local.region2)
    }
  }

  engine_family = "POSTGRESQL"
  debug_logging = true

  # Target Aurora cluster
  target_db_cluster     = true
  db_cluster_identifier = module.aurora_postgresql_v2_secondary.cluster_id

  tags = local.tags
}

