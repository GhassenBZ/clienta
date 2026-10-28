module "network" {
  source = "./modules/network"
}

module "security" {
  source = "./modules/security"

  vpc_id                = module.network.vpc_id
  alb_security_group_id = module.network.alb_security_group_id
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.private_app_subnet_ids[0]
  security_group_id = module.security.app_security_group_id
}
