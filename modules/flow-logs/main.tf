# VPC flow logs, sent to CloudWatch Logs.
#
# Every connection gets logged with source/destination IP, ports, protocol,
# and whether it was ACCEPTed or REJECTed. Basically NetFlow, plus "log" on
# every ACL line. I mostly want the REJECTs, since they show the NACLs and
# security groups are really blocking traffic.

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.tags, { Module = "flow-logs" })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.retention_in_days

  # checkov:skip=CKV_AWS_158:A customer-managed KMS key costs $1/month, so this free-tier lab uses the default AWS encryption.
  # checkov:skip=CKV_AWS_338:Keeping logs for a year makes sense in production. Here short retention keeps it free.

  tags = merge(local.common_tags, { Name = "${var.name}-flow-logs" })
}

# Only the flow logs service, and only for my account, can assume this role.
# The account check stops the "confused deputy" problem.
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.common_tags
}

# The role can write to this one log group and nothing else.
data "aws_iam_policy_document" "write_logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.this.arn,
      "${aws_cloudwatch_log_group.this.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "write-flow-logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.write_logs.json
}

resource "aws_flow_log" "this" {
  vpc_id                   = var.vpc_id
  traffic_type             = var.traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.this.arn
  iam_role_arn             = aws_iam_role.this.arn
  max_aggregation_interval = 60

  tags = merge(local.common_tags, { Name = "${var.name}-flow-log" })
}
