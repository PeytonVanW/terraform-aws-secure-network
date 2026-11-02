# Unit tests for the flow-logs module. Run from modules/flow-logs with: terraform test
# The mock data blocks give the IAM policy and account ID fixed fake values,
# since the mock provider would otherwise fill them with random strings.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name   = "test"
  vpc_id = "vpc-0123456789abcdef0"
}

run "logs_all_traffic_with_short_retention" {
  command = plan

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "Flow logs should capture both ACCEPT and REJECT by default."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 7
    error_message = "Default retention should be 7 days to stay free-tier friendly."
  }
}

run "rejects_unknown_traffic_type" {
  command = plan

  variables {
    traffic_type = "SOME"
  }

  expect_failures = [var.traffic_type]
}
