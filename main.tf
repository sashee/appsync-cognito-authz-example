provider "aws" {
}

data "aws_region" "current" {}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "cognito-test"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "DENY"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}
data "aws_iam_policy_document" "appsync_push_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "dynamodb:GetItem",
			"dynamodb:Query",
			"dynamodb:Scan",
    ]
    resources = [
			aws_dynamodb_table.users.arn,
			aws_dynamodb_table.documents.arn,
    ]
  }
}

resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

# data sources

resource "aws_appsync_datasource" "users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.users.name
  }
}

resource "aws_appsync_datasource" "documents" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "documents"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.documents.name
  }
}

# resolvers

resource "aws_appsync_function" "Query_me_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_me_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"sub": {"S": $util.toJson($ctx.identity.sub)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Query_me" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "me"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_me_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_user_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_user_1"
  request_mapping_template = <<EOF
#if (!$ctx.identity.groups.contains("admin") && $ctx.identity.sub != $ctx.args.sub)
	$util.unauthorized()
#else
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"sub": {"S": $util.toJson($ctx.args.sub)}
	},
	"consistentRead" : true
}
#end
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Query_user" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "user"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_user_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_allUsers_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_user_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_resolver" "Query_allUsers" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "allUsers"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_allUsers_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_documents_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_documents_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"sub": {"S": $util.toJson($ctx.identity.sub)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.qr($ctx.stash.put("user", $ctx.result))
{}
EOF
}

resource "aws_appsync_function" "Query_documents_2" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.documents.name
	name = "Query_documents_2"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#set($results = [])
#foreach($res in $ctx.result.items)
	#if($res.level == "PUBLIC" || $ctx.stash.user.permissions.contains("secret_documents"))
		$util.qr($results.add($res))
	#end
#end
$util.toJson($results)
EOF
}

resource "aws_appsync_resolver" "documents" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "documents"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_documents_1.function_id,
      aws_appsync_function.Query_documents_2.function_id,
    ]
  }
}

# cognito

resource "aws_cognito_user_pool" "pool" {
  name = "test-${random_id.id.hex}"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.pool.id
}


# database

resource "aws_dynamodb_table" "users" {
  name           = "Users-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "sub"

  attribute {
    name = "sub"
    type = "S"
  }
}

resource "aws_dynamodb_table" "documents" {
  name           = "Documents-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# sample data

locals {
	users = tomap({
		user1 = {group: aws_cognito_user_group.user, permissions: ["basic"]},
		user2 = {group: aws_cognito_user_group.user, permissions: ["basic", "secret_documents"]},
		user3 = {group: aws_cognito_user_group.user, permissions: ["basic"]},
		admin = {group: aws_cognito_user_group.admin, permissions: ["basic", "secret_documents"]},
	})
	documents = tomap({
		issue1 = {level: "SECRET", text: "This is a secret document"},
		issue2 = {level: "PUBLIC", text: "This is a public document"},
	})
}

resource "null_resource" "cognito_user" {
	for_each = local.users

  provisioner "local-exec" {
    command = <<EOT
aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-create-user \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--user-attributes "Name=email,Value=${each.key}@example.com" 

aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-add-user-to-group \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--group-name ${each.value.group.name} >&2;

aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-set-user-password \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--password "Password.1" \
	--permanent >&2;
EOT
  }
}

data "external" "user" {
	depends_on = [null_resource.cognito_user]
	for_each = local.users
	program = ["bash", "-c", <<EOT
SUB=$(aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-get-user \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} | jq -r '.UserAttributes[] | select(.Name == "sub") | .Value')

echo "{\"sub\": \"$SUB\", \"object\": \"${each.key}\"}"
EOT
]
}

resource "aws_dynamodb_table_item" "user" {
	for_each = data.external.user
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key
  range_key   = aws_dynamodb_table.users.range_key

  item = <<ITEM
{
  "sub": {"S": "${each.value.result.sub}"},
	"permissions": {"SS": ${jsonencode(local.users[each.value.result.object].permissions)}}
}
ITEM
}

resource "aws_dynamodb_table_item" "issue" {
	for_each = local.documents
  table_name = aws_dynamodb_table.documents.name
  hash_key   = aws_dynamodb_table.documents.hash_key
  range_key   = aws_dynamodb_table.documents.range_key

  item = <<ITEM
{
	"id": {"S": "${each.key}"},
  "level": {"S": "${each.value.level}"},
	"text": {"S": "${each.value.text}"}
}
ITEM
}
