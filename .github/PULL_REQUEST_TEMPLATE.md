# PR Checklist

Please check if your PR fulfills the following requirements
- [ ] The title follows our [guidelines](https://github.com/dchbx/enroll/blob/main/CONTRIBUTING.md#commit
)
- [ ] Tests for the changes have been added (for bugfixes/features)

# PR Type
What kind of change does this PR introduce?

- [ ] Bugfix
- [ ] Feature (requires Feature flag)
- [ ] Inert code (no impact until run, e.g. data fix or migration, manually triggered bulk process, etc.)
- [ ] Refactoring (no functional changes, no API changes)
- [ ] Build related changes
- [ ] CI related changes
- [ ] Dependency updates (e.g., add a new gem or update to a version)
- [ ] Release (Prepares code for a release, e.g., version bumps, changelog updates, tagging, deployment scripts)

# What is the ticket # detailing the issue?

Ticket: 

# A brief description of the changes

Current behavior:

New behavior:

# Feature Flag

For all new feature development, a feature flag is required to control the exposure of the feature to our end users. A feature flag needs a corresponding environment variable to initialize the state of the flag. Please share the name of the environment variable below that would enable/disable the feature and which client(s) it applies to.

Variable name:


# Additional Context
Include any additional context that may be relevant to the peer review process.
