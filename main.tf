provider "aws" {
  region = local.region
}

provider "aws" {
  region = local.region2
  alias = "region2"
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_availability_zones" "secondary" {
  provider = aws.region2
}

locals {
  name   = "ex-${basename(path.cwd)}"
  region = "us-east-1"
  region2 = "us-west-1"

  vpc_cidr                     = "10.0.0.0/16"
  azs                          = slice(data.aws_availability_zones.available.names, 0, 3)
  azs_secondary                = slice(data.aws_availability_zones.secondary.names, 0,2) 
  preferred_maintenance_window = "sun:05:00-sun:06:00"

  tags = {
    Project    = local.name
  }
}




################################################################################
# PostgreSQL Serverless v2
################################################################################

data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "14.5"
}

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = local.name
  engine                    = "aurora-postgresql"
  engine_version            = "14.5"
  database_name             = "aurora_db"
  storage_encrypted         = true
}

module "aurora_postgresql_v2_primary" {
  source = "./modules/aurora_postgresql_v2_primary"

  name              = "${local.name}-postgresqlv2"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "root"
  global_cluster_identifier = aws_rds_global_cluster.this.id
  master_password   = random_password.master.result 
  manage_master_user_password = false
  kms_key_id = aws_kms_key.primary.arn

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  }

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
    #two = {}
  }

  tags = local.tags
}

module "aurora_postgresql_v2_secondary" {
  source = "./modules/aurora_postgresql_v2_secondary"

  providers = {
    aws = aws.region2
  }

  name              = "${local.name}-postgresqlv2"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  #master_username   = "root"
  global_cluster_identifier = aws_rds_global_cluster.this.id
  source_region = local.region
  kms_key_id = aws_kms_key.secondary.arn


  vpc_id               =module.vpc_secondary.vpc_id
  db_subnet_group_name = module.vpc_secondary.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc_secondary.vpc_cidr_block
    }
  }

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
    #two = {}
  }

  depends_on = [ module.aurora_postgresql_v2_primary ]

  tags = local.tags
}

resource "random_password" "master" {
  length  = 20
  special = false
}




################################################################################
# Supporting Resources
################################################################################

data "aws_iam_policy_document" "rds" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        data.aws_caller_identity.current.arn,
      ]
    }
  }

  statement {
    sid = "Allow use of the key"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "monitoring.rds.amazonaws.com",
        "rds.amazonaws.com",
      ]
    }
  }
}

resource "aws_kms_key" "primary" {
  policy = data.aws_iam_policy_document.rds.json
  tags   = local.tags
}

resource "aws_kms_key" "secondary" {
  provider = aws.region2

  policy = data.aws_iam_policy_document.rds.json
  tags   = local.tags
}