provider "aws" {
    region = "us-east-1"
}

resource "aws_dynamodb_table" "event_data_table" {
    name = "event_aggregator_event_data"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "EventID"

    attribute {
      name = "EventID"
      type = "S"
    }

    tags = {
        Name = "event_aggregator_event_data"
        Application = "EventAggregator"
    }
}

resource "aws_dynamodb_table" "summaries_table" {
    name = "event_aggregator_summaries"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "SummaryID"

    attribute {
      name = "SummaryID"
      type = "S"
    }

    tags = {
        Name = "event_aggregator_summaries"
        Application = "EventAggregator"
    }
}