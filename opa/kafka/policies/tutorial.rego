#-----------------------------------------------------------------------------
# High level policy for controlling access to Kafka.
#
# * Deny operations by default.
# * Allow operations if no explicit denial.
#
# The kafka-authorizer-opa plugin will query OPA for decisions at
# /kafka/authz/allow. If the policy decision is _true_ the request is allowed.
# If the policy decision is _false_ the request is denied.
#-----------------------------------------------------------------------------
package kafka.authz

default allow = false

allow {
     not deny
}

#限制消费消息
deny {
     is_read_operation
     topic_contains_pii
     not consumer_is_whitelisted_for_pii
}

#限制生产消息
deny {
  is_write_operation
  topic_has_large_fanout
  not producer_is_whitelisted_for_large_fanout
}

#-----------------------------------------------------------------------------
# Data structures for controlling access to topics. In real-world deployments,
# these data structures could be loaded into OPA as raw JSON data. The JSON
# data could be pulled from external sources like AD, Git, etc.
#-----------------------------------------------------------------------------

consumer_whitelist = {
  "pii": {
     "pii_consumer"
   }
}

producer_whitelist = {
  "large-fanout": {
    "fanout_producer",
  }
}

topic_metadata = {
  "click-stream": {
    "tags": ["large-fanout"],
  },
  "credit-scores": {
    "tags": ["pii"],
  }
}

#-----------------------------------
# Helpers for checking topic access.
#-----------------------------------

topic_contains_pii {
	topic_metadata[topic_name].tags[_] == "pii"
}

consumer_is_whitelisted_for_pii {
	consumer_whitelist.pii[_] == principal.name
}

topic_has_large_fanout {
  topic_metadata[topic_name].tags[_] == "large-fanout"
}

producer_is_whitelisted_for_large_fanout {
  producer_whitelist["large-fanout"][_] == principal.name
}

#-----------------------------------------------------------------------------
# Helpers for processing Kafka operation input. This logic could be split out
# into a separate file and shared. For conciseness, we have kept it all in one
# place.
#-----------------------------------------------------------------------------

is_write_operation {
    input.operation.name == "Write"
}

is_read_operation {
	input.operation.name == "Read"
}

is_topic_resource {
	input.resource.resourceType.name == "Topic"
}

topic_name = input.resource.name {
	is_topic_resource
}

principal = {"fqn": parsed.CN, "name": cn_parts[0]} {
	parsed := parse_user(urlquery.decode(input.session.sanitizedUser))
	cn_parts := split(parsed.CN, ".")
}

parse_user(user) = {key: value |
	parts := split(user, ",")
	[key, value] := split(parts[_], "=")
}