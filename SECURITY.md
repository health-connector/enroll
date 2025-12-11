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

#### CVE-2025-61770

Issue: https://nvd.nist.gov/vuln/detail/CVE-2024-56171

Source: https://github.com/rack/rack/security/advisories/GHSA-p543-xpfm-54cp

**Description:**

```
Rack::Multipart::Parser buffers the entire multipart preamble (bytes before the first boundary) in memory without any size limit. A client can send a large preamble followed by a valid boundary, causing significant memory use and potential process termination due to out-of-memory (OOM) conditions.
```

Notes from the Rack bugtracker state:

```
Remote attackers can trigger large transient memory spikes by including a long preamble in multipart/form-data requests. The impact scales with allowed request sizes and concurrency, potentially causing worker crashes or severe slowdown due to garbage collection.
```

**Mitigation:**

Use a patched version of Rack that enforces a preamble size limit (e.g., 16 KiB) or discards preamble data entirely per [RFC 2046 § 5.1.1](https://www.rfc-editor.org/rfc/rfc2046.html#section-5.1.1).

#### CVE-2025-61771

Issue: https://nvd.nist.gov/vuln/detail/CVE-2025-61771

Source: https://github.com/rack/rack/security/advisories/GHSA-w9pc-fmgc-vxvw

**Description:**

```
Rack::Multipart::Parser stores non-file form fields (parts without a filename) entirely in memory as Ruby String objects. A single large text field in a multipart/form-data request (hundreds of megabytes or more) can consume equivalent process memory, potentially leading to out-of-memory (OOM) conditions and denial of service (DoS).
```

Notes from the Rack bugtracker state:

```
Attackers can send large non-file fields to trigger excessive memory usage. Impact scales with request size and concurrency, potentially leading to worker crashes or severe garbage-collection overhead.
All Rack applications processing multipart form submissions are affected.
```

**Mitigation:**

Use a patched version of Rack that enforces a reasonable size cap for non-file fields (e.g., 2 MiB).

#### CVE-2025-61772

Issue: https://nvd.nist.gov/vuln/detail/CVE-2025-61772

Source: https://github.com/rack/rack/security/advisories/GHSA-wpv5-97wm-hp9c

**Description:**

```
Rack::Multipart::Parser can accumulate unbounded data when a multipart part’s header block never terminates with the required blank line (CRLFCRLF). The parser keeps appending incoming bytes to memory without a size cap, allowing a remote attacker to exhaust memory and cause a denial of service (DoS).
```

Notes from the Rack bugtracker state:

```
Attackers can send incomplete multipart headers to trigger high memory use, leading to process termination (OOM) or severe slowdown. The effect scales with request size limits and concurrency. All applications handling multipart uploads may be affected.
```

**Mitigation:**

Upgrade to a patched Rack version that caps per-part header size (e.g., 64 KiB).

#### CVE-2025-61780

Issue: https://nvd.nist.gov/vuln/detail/CVE-2025-61780

Source: https://github.com/rack/rack/security/advisories/GHSA-p543-xpfm-54cp

**Description:**

```
Rack::Multipart::Parser buffers the entire multipart preamble (bytes before the first boundary) in memory without any size limit. A client can send a large preamble followed by a valid boundary, causing significant memory use and potential process termination due to out-of-memory (OOM) conditions.
```

Notes from the Rack bugtracker state:

```
Remote attackers can trigger large transient memory spikes by including a long preamble in multipart/form-data requests. The impact scales with allowed request sizes and concurrency, potentially causing worker crashes or severe slowdown due to garbage collection.
```

**Mitigation:**

Use a patched version of Rack that enforces a preamble size limit (e.g., 16 KiB) or discards preamble data entirely per [RFC 2046 § 5.1.1](https://www.rfc-editor.org/rfc/rfc2046.html#section-5.1.1).

#### CVE-2025-61919

Issue: https://nvd.nist.gov/vuln/detail/CVE-2025-61919

Source: https://github.com/rack/rack/security/advisories/GHSA-6xw4-3v39-52mm

**Description:**

```
Rack::Request#POST reads the entire request body into memory for Content-Type: application/x-www-form-urlencoded, calling rack.input.read(nil) without enforcing a length or cap. Large request bodies can therefore be buffered completely into process memory before parsing, leading to denial of service (DoS) through memory exhaustion.
```

Notes from the Rack bugtracker state:

```
Attackers can send large application/x-www-form-urlencoded bodies to consume process memory, causing slowdowns or termination by the operating system (OOM). The effect scales linearly with request size and concurrency. Even with parsing limits configured, the issue occurs before those limits are enforced.
```

**Mitigation:**

Update to a patched version of Rack that enforces form parameter limits using query_parser.bytesize_limit, preventing unbounded reads of application/x-www-form-urlencoded bodies.

#### CVE-2025-61921

Issue: https://nvd.nist.gov/vuln/detail/CVE-2025-61921

Source: https://github.com/rack/rack/security/advisories/GHSA-6xw4-3v39-52mm

**Description:**

```
There is a denial of service vulnerability in the If-Match and If-None-Match header parsing component of Sinatra, if the etag method is used when constructing the response and you are using Ruby < 3.2.
```

Notes from the sinatra bugtracker state:

```
Carefully crafted input can cause If-Match and If-None-Match header parsing in Sinatra to take an unexpected amount of time, possibly resulting in a denial of service attack vector. This header is typically involved in generating the ETag header value. Any applications that use the etag method when generating a response are impacted if they are using Ruby below version 3.2.