from constructs import Construct
from aws_cdk import (
    Duration,
    App, Stack,
    aws_s3 as s3,
    aws_iam as iam,
    aws_lambda as lambda_,
    BundlingOptions,
    aws_events as events,
    aws_events_targets as targets,
    aws_secretsmanager as sm,
)

# STACK=nft-test CHAIN_ID=8 NFT_CONTRACT=free.nft-mint POLICY_CONTRACT=free.nft-policy COLLECTION=nft-test cdk deploy --profile nft
# STACK=nft CHAIN_ID=8 NFT_CONTRACT=free.nft-mint POLICY_CONTRACT=free.nft-policy COLLECTION=nft-prod cdk deploy --profile nft
import os
STACK = os.environ['STACK']
CHAIN_ID = os.environ['CHAIN_ID']
NFT_CONTRACT = os.environ['NFT_CONTRACT']
POLICY_CONTRACT = os.environ['POLICY_CONTRACT']
COLLECTION = os.environ['COLLECTION']


from pathlib import Path
THIS_DIR = Path(__file__).parent

RESOURCES_DIR = THIS_DIR / "resources"
REVEAL_FUNCTION_DIR = RESOURCES_DIR / "nft-reveal-handler"

class NFTStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        secret_name = f'{STACK}-OpsKeyset'
        secret = sm.Secret(self,
          "Ops",
          secret_name=secret_name)

        bucket = s3.Bucket(
          self, 
          "nftbucket", 
          cors=[
            s3.CorsRule(
              allowed_methods=[s3.HttpMethods.GET],
              allowed_origins=["*"],
            )
          ]
        )

        # Create the IAM policy statement that allows public read access to objects with the tag "revealed: yes"
        policy_statement = iam.PolicyStatement(
            effect=iam.Effect.ALLOW,
            principals=[iam.ArnPrincipal("*")],
            actions=[
                "s3:GetObject"
            ],
            resources=[
                bucket.bucket_arn + "/*"
            ],
            conditions={
                "StringEquals": {
                    "s3:ExistingObjectTag/revealed": "yes"
                }
            }
        )

        # Let normal user read and write to it
        # bucket.grant_read_write(iam.AccountRootPrincipal())

        # Add the policy statement to the S3 bucket's policy
        bucket.add_to_resource_policy(policy_statement)

        handler = lambda_.Function(self, "nft-reveal-handler-test",
            runtime=lambda_.Runtime.PYTHON_3_9,
            code=lambda_.Code.from_asset(
              str(REVEAL_FUNCTION_DIR),
              bundling=BundlingOptions(
                image=lambda_.Runtime.PYTHON_3_9.bundling_image,
                command=[
                  "bash", "-c", "pip install -r requirements.txt -t /asset-output && cp -au . /asset-output"
                ]
              ),
            ),
            handler="lambda_function.lambda_handler",
            timeout=Duration.seconds(300),
            environment=dict(
              SECRET_NAME=secret_name,
              BUCKET=bucket.bucket_name,
              REGION='us-west-2',
              KADENA_NODE_URL="https://api.chainweb.com",
              CHAIN_ID=CHAIN_ID,
              NFT_CONTRACT=NFT_CONTRACT,
              POLICY_CONTRACT=POLICY_CONTRACT,
              COLLECTION=COLLECTION
            )
        )

        secret.grant_read(handler)
        bucket.grant_read_write(handler)
        

        # Create a CloudWatch Event rule that triggers the Lambda function every 60 seconds
        rule = events.Rule(self, "every-minute",
                           schedule=events.Schedule.expression("rate(1 minute)"),
                           enabled=True)

        # Add a permission to the Lambda function to allow the CloudWatch Events service to invoke it
        handler.add_permission(
          id="InvokePermission",
          action="lambda:InvokeFunction",
          principal=iam.ServicePrincipal("events.amazonaws.com"),
          source_arn=rule.rule_arn
        )

        rule.add_target(targets.LambdaFunction(handler))


app = App()

NFTStack(app, STACK)
app.synth()