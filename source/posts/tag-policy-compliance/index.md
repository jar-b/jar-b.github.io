# Tag Policy Compliance

**2026-02-20**

---

In the lead up to AWS Re:Invent 2025, the Terraform AWS Provider added support for [enforcing tag policy compliance](https://github.com/hashicorp/terraform-provider-aws/pull/45143).
The user-facing portion of this feature is covered in the [provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/tag-policy-compliance), but there are some interesting internal implementation details worth describing further.

- [Mapping Resource Types](#mapping-resource-types)
- [Retrieving Tag Policy Data](#retrieving-tag-policy-data)
- [Validation Timing](#validation-timing-and-plugin-libraries)

## Mapping Resource Types 

[Tag policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html) provide a mechanism for organizations to monitor and enforce tagging practices on any AWS resource which supports tags.
To re-use an example from the provider documentation, this policy dictates all Log Groups should have the `Owner` tag.

```json
{
  "tags": {
    "Owner": {
      "tag_key": {
        "@@assign": "Owner"
      },
      "report_required_tag_for": {
        "@@assign": [
          "logs:log-group"
        ]
      }
    }
  }
}
```

The `@@assign` array is where the resource type(s) are defined, in this case it contains only `logs:log-group`.
This is a "tag type", which is distinct from resource type names for CloudFormation or Terraform.

This presents the first challenge with implementing provider support for tag compliance - translating a "tag type" to a "Terraform type" to ensure the policy intent still applies correctly.

For the initial release we kept the solution simple and [generated a `map`](https://github.com/hashicorp/terraform-provider-aws/blob/v6.22.0/internal/tags/tagpolicy/lookup_gen.go#L7-L9) from [a source CSV](https://github.com/hashicorp/terraform-provider-aws/blob/v6.22.0/internal/tags/tagpolicy/tagris-cfn-terraform-mapping.csv) correlating tag, CloudFormation, and Terraform resource types.
A fast follow [migrated the CSV to HCL](https://github.com/hashicorp/terraform-provider-aws/pull/45671), and added support one-to-many type mappings.

While this lacks a fully automated mechanism to account for new tag types[^1], it provides a stable source of truth with very low maintenance burden in the short-to-medium term.

[^1]: Any automated solution would be predicated on the public availability of an API to list all supported tag resource types.

## Retrieving Tag Policy Data

With the capability for translating tag policies in place, another decision point was _when_ to fetch tag policy data within the provider life cycle.
Broadly, the two options considered were:

1. Fetch required tags for all resources at startup.
1. Fetch required tags for one resource type on-demand.

Both options have trade-offs, but in this case we chose Option 1 to optimize for configurations with many resources.

It is common for single Terraform configurations to have tens or hundreds of resources, most of which will support tags.
By fetching and caching the tag policy data during provider initialization, we avoid introducing tens or hundreds of additional API calls to fetch required tagging data per each resource type.
Reducing to a single API call also reduces the likelihood of failed requests or throttling errors in the middle of a `plan` operation.

## Validation Timing

Perhaps the most technically interesting aspect of this feature is where the validation executes.

Validation occurs during the [`PlanResourceChange` RPC](https://developer.hashicorp.com/terraform/plugin/framework/internals/rpcs#planresourcechange-rpc).
For Plugin SDK V2 based resources, this is a [`CustomizeDiff` method](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/customizing-differences).
For Plugin Framework based resources, this is a [`ModifyPlan` method](https://developer.hashicorp.com/terraform/plugin/framework/resources/plan-modification#resource-plan-modification).
These methods can be defined individually per resource, but in the AWS provider we also have a concept of "interceptors".

Interceptors function as a middleware by wrapping resource definitions in a parent struct and applying generalized logic to _all_ resources.
The logic can run before or after the wrapped resource's, and extends CRUD operations as well as plan-stage operations like `CustomizeDiff`/`ModifyPlan`.
This is how tagging and resource identity function without any boilerplate code in the resource file related to these operations.

For tag policy compliance we added two new interceptors that append to existing `CustomizeDiff` / `ModifyPlan` functions for any resources which support tags.
The code for each is found ([here](https://github.com/hashicorp/terraform-provider-aws/blob/v6.22.1/internal/provider/sdkv2/tags_interceptor.go#L303-L364)) and ([here](https://github.com/hashicorp/terraform-provider-aws/blob/v6.22.1/internal/provider/framework/tags_interceptor.go#L273-L335)). [^2]

Interceptors allowed us to write the validation logic once and apply it consistently to the hundreds of resources across the provider.

[^2]: These link to the interceptor logic as of `v6.22.1`.
The initial release in `v6.22.0` contained a pair of significant regressions.
See the [patch PR](https://github.com/hashicorp/terraform-provider-aws/pull/45201) for a detailed write up on what was missed.
