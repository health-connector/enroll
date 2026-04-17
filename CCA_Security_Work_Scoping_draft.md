# CCA Security Work Scoping

Some initiatives replace or upgrade **third-party components that are end-of-life (EOL) and no longer receive security support** (notably CKEditor and DataTables). Other initiatives **reduce security risk and operational complexity** (for example, dead code removal, Mongoid `Dynamic`, unused indexes, and legacy acapi listeners).

## Remove aca_entities dependency from MA Enroll (High/Urgent) (MA only)

- Outcome: the enroll app does not include the aca_entities gem; Premium Value Product (PVP) functionality is unaffected and works exactly as it did before

## Establish Security Baseline (code and dependency scanning) post Ruby on Rails 8.1 / Ruby 3.2 upgrade (High) (all clients)
- For all repos, generate a report of all the security vulnerabilities in the codebase currently flagged by the following tools (where applicable):
  - Bearer
  - Brakeman
  - CodeQL
  - Bundler audit
  - Anchore / Grype (for Docker images)
- Break down the findings by severity and vulnerability type

## Remediation of security vulnerabilities (High) (all clients)
- Remediate findings from the security baseline report in order of severity, starting with critical vulnerabilities
- Outcome: the goal is to eliminate all findings; the MVP is remediation of critical- and high-severity findings

## Ongoing maintenance strategy proposal (High) (all clients)
- Outcome: a **written process** for remediating security vulnerabilities as part of normal operations and maintenance

## Analysis of all feature flags (High) (all clients)

- Outcome: a **single document** listing every feature flag with the information below, suitable for review and approval by lead engineers, product, and leadership
- The document should include, for each flag:
  - Environment variable name used to enable/disable the feature flag (if applicable)
  - Any settings plus associated environment variables (if applicable)
  - Current setting in Production (enabled or disabled); note: must be based on the Kubernetes env ConfigMap if an environment variable is used to set the value
  - Brief description of what the feature flag is for (functionality and high-level code path)
  - When it was added
  - Whether the feature flag is intended to be long-lived (i.e., it controls some client config) or short-lived (i.e., it was added to support trunk-based development)
  - A recommendation on whether to remove the feature flag or keep it
  - Open questions that must be answered to support a high-confidence recommendation

## Upgrade Debian and Node versions (High) (all clients)

- Outcome: Debian 13 (trixie) and Node 24 are used to build the images
- Note: This may be handled by the DevOps team

## Make sure all our security GHAs are in all the repos (High)

**CURRENTLY ONLY VIABLE IN IC REPOS; DC AND MA REQUIRE CLIENT COMMUNICATION AND APPROVAL**

- Need to validate how we will define "all the repos"; likely need to get a list approved by the lead engineers
- Five code scanning tools (align with security baseline where applicable):
  - Bearer (must **fail the build** when it reports vulnerabilities; not advisory-only)
  - Brakeman (must **fail the build** when it reports vulnerabilities; not advisory-only)
  - CodeQL (must **fail the build** when it reports vulnerabilities; not advisory-only)
  - Bundler audit (must **fail the build** when it reports vulnerabilities; not advisory-only)
  - Anchore / Grype (for Docker images)
- For IC repos, we have full control of this. This means confirming/adding all the tools to the following repos:
  - enroll
  - medicaid_gateway
  - fdsh_gateway
  - edi_gateway
  - polypress
  - aca_entities
  - resource_registry
  - event_source
  - fti
  - console
  - crm_gateway
  - identity_provider_gateway
  - medicaid_eligibility
  - cartafact
  - glue?
  - quoting_tool

## Dead code cleanup (High) (all clients)

- Outcome (phase 1): generate a report of dead code in the codebase, including:
  - Description of the functionality
  - Justification for why the code is dead (e.g., it was moved to a different namespace, it was replaced by a new feature, it was abandoned during development, etc.)
  - Locations in the codebase and code paths
  - Recommendation with confidence level for how to remove the code
  - Open questions that must be answered to support high-confidence cleanup
  - Notes on what should be done for regression testing to ensure removal did not break anything
- Outcome (phase 2): determine which cleanup efforts are safest and most feasible given project constraints, then remove the code

## Data anonymization of DB dumps (High) (all clients)

- First, present the technical solution to the lead engineers and obtain approval
- Outcome: produce an anonymized data dump that developers and QAs can use locally for testing, debugging, and feature development, thus reducing reliance on remote environments
- The anonymized dump is intended to **feed the local Kubernetes QA setup** (below), but **neither effort should block the other**; each can advance on its own timeline

## Set up local Kubernetes cluster and test data dump for QA (High) (MA and DC only)

- Outcome: QAs can run the app locally via Kubernetes and pre-built images together with a data dump (including, when available, the **anonymized** dump from the effort above), thereby reducing the need for QA testing against remote environments
- This work can proceed **in parallel** with anonymized dump production; use mock or other interim data where the anonymized dump is not ready yet

## CKEditor (Medium) (all clients)

- Rationale: current dependency stack is **EOL** and does not receive security fixes; upgrade or replacement is a security-driven change
- Confirm alignment on an agreed-upon approach for upgrading or replacing CKEditor internally
- Communicate to the client the impacts of the approach (e.g., licensing fees, UI changes for notice templates, etc.)
- Estimate effort and time to complete the agreed-upon approach

## DataTables (Medium) (MA only for POC; eventually all clients)

- Rationale: current dependency stack is **EOL** and does not receive security fixes; replacement is a security-driven change
- Implement and test a POC for replacing DataTables in a deployed environment with production-like data
- Communicate to the client any impacts of replacing DataTables (e.g., tables may look different in the UI, etc.)

## Removal of "Mongoid::Attributes::Dynamic" (Medium) (all clients)

- Outcome: no models in the codebase use the `Mongoid::Attributes::Dynamic` module

## Clean up all unwanted or unneeded indexes (Low) (all clients)

This work is needed because such indexes slow database writes and affect performance.

- Outcome: no unwanted or unneeded indexes remain in the codebase

## Clean up all legacy acapi listeners that are not in use today (Low) (all clients)

- Outcome: no legacy acapi listeners remain in the codebase
