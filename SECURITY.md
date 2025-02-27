# Security Policy

## Vulnerability Mitigations

### CVE-2024-21510 - Sinatra

**Vulnerability:** Sinatra vulnerable to Reliance on Untrusted Inputs in a Security Decision

**Mitigation:** This vulnerability affects Sinatra when used for parsing HTTP requests. In our application, Sinatra is not directly used for this purpose. It is a dependency of Resque, which we use for background job processing. The vulnerable component of Sinatra is not exercised in our usage context, therefore the risk is minimal.

**Actions Taken:**
1. We have documented this issue and our mitigation strategy.
2. We are monitoring for updates to Resque that might include a patched version of Sinatra.
3. We have verified that our usage of Resque does not expose Sinatra to untrusted input in our application setup.
4. We have configured bundler-audit to ignore this specific vulnerability in our CI/CD pipeline.

**Ongoing Measures:**
1. Regular review of dependencies and their security advisories.
2. Periodic assessment of our usage of Resque to ensure it remains unexposed to the vulnerable Sinatra components.

### Advisory GHSA-vfm5-rmrh-j26v - Action Dispatch 2024-12-10

**Vulnerability:**

Source: https://github.com/rails/rails/security/advisories/GHSA-vfm5-rmrh-j26v

NVD: https://nvd.nist.gov/vuln/detail/CVE-2024-54133

There is a possible Cross Site Scripting (XSS) vulnerability in the content_security_policy helper in Action Pack.

Applications which set Content-Security-Policy (CSP) headers dynamically from untrusted user input may be vulnerable to carefully crafted inputs being able to inject new directives into the CSP. This could lead to a bypass of the CSP and its protection against XSS and other attacks.

**Mitigation:**

No mitigation required as we are not vulnerable.

We do not dynamically set our CSP values using user input.

This specific security advisory has been added to the bundler audit ignore file.

### Advisory GHSA-vvfq-8hwr-qm4m - Nokogiri 2025-02-18

#### Vulnerability

Source: https://github.com/sparklemotion/nokogiri/security/advisories/GHSA-vvfq-8hwr-qm4m

This advisory addresses two separate vulnerabilities:
1. CVE-2025-24928
2. CVE-2024-56171

These vulnerabilities are present in the underlying `libxml2` implementation packaged with Nokogiri versions `< 1.18.3`.

#### CVE-2025-24928

NVD: https://nvd.nist.gov/vuln/detail/CVE-2025-24928

Source: https://gitlab.gnome.org/GNOME/libxml2/-/issues/847

**Description:**

```
libxml2 before 2.12.10 and 2.13.x before 2.13.6 has a stack-based buffer overflow in xmlSnprintfElements in valid.c. To exploit this, DTD validation must occur for an untrusted document or untrusted DTD. NOTE: this is similar to CVE-2017-9047.
```

Notes from the libxml2 bugtracker state:

```
This issue only affects DTD validation of untrusted XML documents or validation against untrusted DTDs. It can be triggered by passing the XML_PARSE_DTDVALID parser option or by calling one of the DTD validation functions like xmlValidateDocument or xmlValidateDtd.
```

**Mitigation:**

There are few endpoints in Enroll which accept XML data.  Of those, none perform DTD validation.  As explotation requires the execution of DTD validation against a crafted XML document, Enroll is not considered vulnerable.

#### CVE-2024-56171

NVD: https://nvd.nist.gov/vuln/detail/CVE-2024-56171

Source: https://gitlab.gnome.org/GNOME/libxml2/-/issues/828

**Description:**

```
libxml2 before 2.12.10 and 2.13.x before 2.13.6 has a use-after-free in xmlSchemaIDCFillNodeTables and xmlSchemaBubbleIDCNodeTables in xmlschemas.c. To exploit this, a crafted XML document must be validated against an XML schema with certain identity constraints, or a crafted XML schema must be used.
```

Notes from the libxml2 bugtracker state:

```
This issue affects validation against untrusted XML Schemas (.xsd) and, potentially, validation of untrusted documents against trusted Schemas if they make use of xsd:keyref in combination with recursively defined types that have additional identity constraints. It's hard for me to judge whether this is common in practice.
```

**Mitigation:**

There are few endpoints in Enroll which accept XML data.  Of those, none perform validation using an XML schema which contains usage of the xsd:keyref construct.  As explotation requires these conditions, Enroll is not considered vulnerable.

#### Actions Taken

Given that Enroll is not considered vulnerable against either underlying CVE, this specific security advisory has been added to the bundler audit ignore file.