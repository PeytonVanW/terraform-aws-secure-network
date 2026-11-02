# TFLint finds problems that `terraform validate` lets through, like unused
# variables, inputs or outputs with no description, and AWS values that don't
# exist (a typo in an instance type, for example). Pre-commit and `make lint`
# both read this file, so every check runs the same rules.

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}
