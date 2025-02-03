### Get Hosted Zone ID from Route 53

Copy the Route 53 Zone ID for the zone you want cert-manager to create certificates for

```shell
aws route53 list-hosted-zones
```

### Create Route 53 Policy and user for Cert Manager

Create a Route 53 Policy to allow cert-manager permission to manage the domain.

```json
//letsencrypt-wildcard.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ChangeResourceRecordSets",
      "Resource": "arn:aws:route53:::hostedzone/<zone-id-from-previous-step>"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

Next, apply the policy to Route 53 using the AWS CLI:

```shell
 aws iam create-policy --policy-name letsencrypt-wildcard --policy-document file://letsencrypt-wildcard.json
```

The command will return a JSON document with details about the newly-created policy.

Next, create a letsencrypt user to interact with Route 53:

Get the policy ARN

```shell
# Get the Policy ARN
LE_POLICY_ARN=$(aws iam list-policies --output json --query 'Policies[*].[PolicyName,Arn]' --output text | grep letsencrypt-wildcard | awk '{print $2}')
```

Create user and group

```shell
aws iam create-group --group-name letsencrypt-wildcard

aws iam attach-group-policy --policy-arn ${LE_POLICY_ARN} --group-name letsencrypt-wildcard

aws iam create-user --user-name letsencrypt-wildcard
aws iam add-user-to-group --user-name letsencrypt-wildcard --group-name letsencrypt-wildcard

aws iam create-access-key --user-name letsencrypt-wildcard
```

Save the access key credentials to AWS Parameter Store. The permissions above allow the newly-created user to manage manage resources in Route 53.

### Create a Policy to manage secrets in AWS Parameter Store

This policy allows trusted user accounts to add, list and delete secrets that match the path defined in "Resource". Create this file on your computer

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:GetParameterHistory",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:DeleteParameters"
      ],
      "Resource": "arn:aws:ssm:eu-west-1:12345678901:parameter/path/to/secret/*"
    },
    {
      "Effect": "Allow",
      "Action": "ssm:DescribeParameters",
      "Resource": "*"
    }
  ]
}
```

Replace the "Resource" section with your ARN

https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html

Run the following command to create it using the AWS CLI:

```shell
aws iam create-policy --policy-name prod-kubernetes-cluster-parameter-store-access --policy-document file://parameter-store-prod.json
```

To add the policy to the user account, retrieve it's ARN:

```shell
SSM_POLICY=$(aws iam list-policies --output json --query 'Policies[*].[PolicyName,Arn]' --output text | grep prod-kubernetes-cluster-parameter-store-access | awk '{print $2}')
```

And now, to add the policy to the user account:

```shell
aws iam attach-group-policy --policy-arn ${SSM_POLICY} --group-name kubernetes-prod
```

The user now has permissions to manage domain resources in Route 53 and prod secrets in Parameter Store.
