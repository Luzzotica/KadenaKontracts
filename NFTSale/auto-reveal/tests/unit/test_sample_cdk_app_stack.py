import aws_cdk as core
import aws_cdk.assertions as assertions

from sample_cdk_app.sample_cdk_app_stack import SampleCdkAppStack

# example tests. To run these tests, uncomment this file along with the example
# resource in sample_cdk_app/sample_cdk_app_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = SampleCdkAppStack(app, "sample-cdk-app")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
