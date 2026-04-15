<!-- EXAMPLE RULE: AWS & CDK
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers AWS CDK for TypeScript — import style, IAM principles,
  CLI conventions. Delete if you don't use AWS, or replace with your cloud
  provider's conventions. -->

# AWS Standards

## CDK Style Preferences
- Any time I want to build something that uses AWS infrastructure, always assume it will use the AWS CDK for Typescript to deploy that infrastructure, unless I explicitly say I want to use something else.
- Always use the most recent version of the AWS CDK for Typescript.
- Always use destructured imports for CDK constructs.
- When no project-specific helper exists, prefer L2 constructs over L1.
- Use meaningful construct IDs that reflect their purpose.
- Follow least privilege principle for IAM policies.
- Before creating IAM policies, always make sure they are absolutely necessary and are not achievable through any built in methods.
- Example: `import { Stack } from 'aws-cdk-lib'` not `import * as cdk from 'aws-cdk-lib'`.
- Group imports: external packages, then internal modules, then relative imports.

## IAM-Code Coupling (CRITICAL)
- **IAM policies and the runtime code they govern are tightly coupled but have no compile-time connection.** Changes to one side must always trigger a review of the other.
- **When changing what a Lambda calls** (different Bedrock model, different DynamoDB table, different S3 bucket, different API, new SDK call) → check the Lambda's IAM policy to confirm it grants access to the new resource/action. A valid SDK call with the wrong IAM permission fails silently at runtime with `AccessDeniedException`.
- **When changing an IAM policy** (different resource ARN, different action, narrowing scope) → check the Lambda's runtime code to confirm it still falls within the granted permissions.
- **Cross-check checklist** — whenever modifying a Lambda handler or its IAM grants, verify:
  1. Every `client.send()` / SDK call has a matching IAM `actions` entry
  2. Every resource ARN in the IAM policy matches the actual resource identifier used in code (model IDs, table names, bucket names, etc.)
  3. Resource identifiers are shared constants (not hardcoded separately in CDK and Lambda code) to prevent drift
- **CDK grant methods** (e.g., `table.grantReadData(fn)`, `bucket.grantRead(fn)`) handle this coupling automatically. Prefer them over manual `PolicyStatement` whenever available. Only use manual IAM statements when no grant method exists for the service or action.

## AWS CLI
- Use --no-cli-pager for all aws-cli commands to avoid pagination.
- When AWS SSO tokens expire, run `aws sso login --profile <profile>` directly instead of asking the user to do it.
