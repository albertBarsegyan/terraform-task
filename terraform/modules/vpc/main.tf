module "this" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "5.19.0"
  name                 = var.name
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  public_subnet_tags   = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags  = { "kubernetes.io/role/internal-elb" = "1" }
  tags                 = var.tags
}
