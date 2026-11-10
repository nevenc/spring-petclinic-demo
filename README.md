# Spring PetClinic: Spring Boot versions and CVEs

This demo shows how the security posture of the same application ([Spring PetClinic](https://github.com/spring-projects/spring-petclinic)) changes across Spring Boot versions. It goes from an old Spring Boot 2.7.x release, through the latest 2.7.x and 3.5.x patch releases and two ways of patching dependencies, to Spring Boot 4.x.

Each version lives in its own Git submodule, and each one has a Cloud Foundry manifest (`manifest-<version>.yaml`) in this folder.

## Projects

| # | Project | Spring Boot | Java | Dependencies from | Notes |
|---|---|---|---|---|---|
| 1 | [`spring-petclinic-2.7.3`](spring-petclinic-2.7.3) | 2.7.3 | 8 | Maven Central | Old 2.7.x release (Aug 2022) |
| 2 | [`spring-petclinic-2.7.18`](spring-petclinic-2.7.18) | 2.7.18 | 17 | Maven Central | Last open-source 2.7.x release |
| 3 | [`spring-petclinic-2.7.35`](spring-petclinic-2.7.35) | 2.7.35 | 17 | Spring Enterprise repo | Commercial 2.7.x extended support |
| 4 | [`spring-petclinic-3.5.16`](spring-petclinic-3.5.16) | 3.5.16 | 17 | Maven Central | |
| 5 | [`spring-petclinic-3.5.17`](spring-petclinic-3.5.17) | 3.5.17 | 17 | Spring Enterprise repo | Commercial 3.5.x |
| 6 | [`spring-petclinic-3.5.17-patched`](spring-petclinic-3.5.17-patched) | 3.5.17 | 17 | Spring Enterprise repo | 3.5.17 plus overridden versions of the vulnerable dependencies |
| 7 | [`spring-petclinic-3.5.17-manually-patched`](spring-petclinic-3.5.17-manually-patched) | 3.5.17 | 17 | Spring Enterprise repo | As above, plus a manual Log4j override (`log4j2.version=2.25.5`) |
| 8 | [`spring-petclinic-4.0.9`](spring-petclinic-4.0.9) | 4.0.9 | 25 | Maven Central | |
| 9 | [`spring-petclinic-4.1.2`](spring-petclinic-4.1.2) | 4.1.2 | 25 | Maven Central | |

### What "patched" means

**`3.5.17-patched`** keeps Spring Boot 3.5.17. In `<dependencyManagement>` (Maven) and `dependencyManagement` (Gradle), it overrides the versions of the libraries that trivy flags:

| Dependency | 3.5.17 (Boot-managed) | Patched to |
|---|---|---|
| `org.apache.tomcat.embed:tomcat-embed-core` / `-el` / `-websocket` | 10.1.57 | 10.1.61 |
| `com.fasterxml.jackson.core:jackson-core` / `jackson-databind` + Jackson modules | 2.21.5 | 2.21.8 |
| `org.hibernate.orm:hibernate-core` | (managed) | 6.6.59.Final |
| `org.slf4j:slf4j-api` / `jul-to-slf4j` | (managed) | 2.0.20 |
| `org.thymeleaf:thymeleaf` / `thymeleaf-spring6` | (managed) | 3.1.6.RELEASE |

**`3.5.17-manually-patched`** has the same overrides, plus `log4j2.version` set to `2.25.5`. That fixes the last remaining finding, CVE-2026-49844 in `log4j-api` 2.24.3.

## Building and deploying

Each project builds with either Maven or Gradle:

```bash
cd spring-petclinic-3.5.17
./mvnw clean package      # -> target/spring-petclinic-3.5.17.jar
# or
./gradlew clean build     # -> build/libs/spring-petclinic-3.5.17.jar
```

To deploy to Cloud Foundry from this folder:

```bash
cf push -f manifest-3.5.17.yaml
```

The manifests use `java_buildpack_offline` and pick the JRE that matches each project: 8 for 2.7.3, 17 for 2.7.18 through 3.5.17, and 25 for 4.x.

The projects that use the Spring Enterprise repository (2.7.35 and all three 3.5.17 projects) need Broadcom Spring Enterprise credentials. Put them in `~/.m2/settings.xml` for Maven, or in the Gradle properties for Gradle.

## Trivy scan results

Each project was scanned on its own by running `trivy repo .` inside the project directory.

- **Scanned on:** 2026-11-11
- **Trivy:** 0.76.2
- **Vulnerability DB:** updated 2026-11-10 10:23 UTC

To re-run every scan and regenerate the reports:

```bash
./trivy-scan.sh
```

The script writes one full table report per project to [`trivy-reports/`](trivy-reports) (`<project>.txt`) and the summary table to `trivy-reports/SUMMARY.md`. The raw JSON reports are git-ignored.

### Summary

| Project | Critical | High | Medium | Low | **Total** |
|---|---:|---:|---:|---:|---:|
| spring-petclinic-2.7.3 | 19 | 55 | 48 | 13 | **135** |
| spring-petclinic-2.7.18 | 17 | 48 | 42 | 14 | **121** |
| spring-petclinic-2.7.35 | 7 | 12 | 15 | 4 | **38** |
| spring-petclinic-3.5.16 | 7 | 7 | 8 | 0 | **22** |
| spring-petclinic-3.5.17 | 4 | 5 | 3 | 0 | **12** |
| spring-petclinic-3.5.17-patched | 0 | 0 | 1 | 0 | **1** |
| spring-petclinic-3.5.17-manually-patched | 0 | 0 | 0 | 0 | **0** |
| spring-petclinic-4.0.9 | 0 | 0 | 0 | 0 | **0** |
| spring-petclinic-4.1.2 | 0 | 0 | 0 | 0 | **0** |

Notes on how to read these numbers:

- **Counts are trivy findings,** meaning (CVE, package) pairs, as reported in trivy's `Total:` line. A few CVEs affect more than one package; for example, the same Thymeleaf CVE hits both `thymeleaf` and `thymeleaf-spring5`. Counted as unique CVE IDs instead, the totals are 130 (2.7.3), 116 (2.7.18) and 35 (2.7.35). The other projects don't change.
- **Only `pom.xml` produces findings.** `trivy repo` resolves the Maven dependency tree from `pom.xml`. It doesn't scan `build.gradle` (there's no Gradle lockfile) or the built jars in `target/` and `build/libs/`. The only other target trivy reports is a JaCoCo agent `pom.xml` under `build/tmp/`, with 0 findings in every project.
- **No secrets** were found in any project.

### Affected packages per project

Columns are Critical / High / Medium / Low.

#### spring-petclinic-2.7.3 (135)

| Package | Version | C | H | M | L |
|---|---|---:|---:|---:|---:|
| `org.apache.tomcat.embed:tomcat-embed-core` | 9.0.65 | 8 | 21 | 12 | 4 |
| `org.thymeleaf:thymeleaf` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.thymeleaf:thymeleaf-spring5` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.springframework:spring-webmvc` | 5.3.22 | 2 | 4 | 9 | 2 |
| `org.springframework:spring-web` | 5.3.22 | 1 | 3 | 2 | 0 |
| `org.postgresql:postgresql` | 42.3.6 | 1 | 2 | 1 | 0 |
| `org.springframework.boot:spring-boot-actuator-autoconfigure` | 2.7.3 | 1 | 0 | 0 | 0 |
| `com.fasterxml.jackson.core:jackson-databind` | 2.13.3 | 0 | 6 | 7 | 0 |
| `org.springframework:spring-expression` | 5.3.22 | 0 | 3 | 3 | 1 |
| `com.fasterxml.jackson.core:jackson-core` | 2.13.3 | 0 | 3 | 0 | 0 |
| `org.yaml:snakeyaml` | 1.30 | 0 | 2 | 5 | 0 |
| `org.springframework.boot:spring-boot` | 2.7.3 | 0 | 2 | 0 | 0 |
| `ch.qos.logback:logback-core` | 1.2.11 | 0 | 1 | 2 | 4 |
| `org.springframework.data:spring-data-commons` | 2.7.2 | 0 | 1 | 2 | 0 |
| `org.springframework.boot:spring-boot-autoconfigure` | 2.7.3 | 0 | 1 | 1 | 0 |
| `org.springframework:spring-core` | 5.3.22 | 0 | 1 | 0 | 1 |
| `ch.qos.logback:logback-classic` | 1.2.11 | 0 | 1 | 0 | 0 |
| `com.h2database:h2` | 2.1.214 | 0 | 1 | 0 | 0 |
| `io.micrometer:micrometer-core` | 1.9.3 | 0 | 1 | 0 | 0 |
| `mysql:mysql-connector-java` | 8.0.30 | 0 | 1 | 0 | 0 |
| `org.springframework.boot:spring-boot-starter-actuator` | 2.7.3 | 0 | 1 | 0 | 0 |
| `org.springframework:spring-context` | 5.3.22 | 0 | 0 | 1 | 1 |
| `org.apache.logging.log4j:log4j-api` | 2.17.2 | 0 | 0 | 1 | 0 |
| `org.apache.tomcat.embed:tomcat-embed-websocket` | 9.0.65 | 0 | 0 | 1 | 0 |
| `org.springframework.boot:spring-boot-actuator` | 2.7.3 | 0 | 0 | 1 | 0 |

#### spring-petclinic-2.7.18 (121)

| Package | Version | C | H | M | L |
|---|---|---:|---:|---:|---:|
| `org.apache.tomcat.embed:tomcat-embed-core` | 9.0.83 | 8 | 18 | 9 | 5 |
| `org.thymeleaf:thymeleaf` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.thymeleaf:thymeleaf-spring5` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.springframework:spring-webmvc` | 5.3.31 | 1 | 4 | 9 | 2 |
| `org.springframework:spring-web` | 5.3.31 | 1 | 3 | 2 | 0 |
| `org.postgresql:postgresql` | 42.3.8 | 1 | 1 | 0 | 0 |
| `com.fasterxml.jackson.core:jackson-databind` | 2.13.5 | 0 | 4 | 7 | 0 |
| `com.fasterxml.jackson.core:jackson-core` | 2.13.5 | 0 | 3 | 0 | 0 |
| `org.yaml:snakeyaml` | 1.30 | 0 | 2 | 5 | 0 |
| `ch.qos.logback:logback-core` | 1.2.12 | 0 | 2 | 2 | 4 |
| `org.springframework:spring-expression` | 5.3.31 | 0 | 2 | 2 | 1 |
| `org.springframework.boot:spring-boot` | 2.7.18 | 0 | 2 | 0 | 0 |
| `org.springframework.data:spring-data-commons` | 2.7.18 | 0 | 1 | 2 | 0 |
| `org.springframework:spring-core` | 5.3.31 | 0 | 1 | 0 | 1 |
| `ch.qos.logback:logback-classic` | 1.2.12 | 0 | 1 | 0 | 0 |
| `com.h2database:h2` | 2.1.214 | 0 | 1 | 0 | 0 |
| `com.mysql:mysql-connector-j` | 8.0.33 | 0 | 1 | 0 | 0 |
| `io.micrometer:micrometer-core` | 1.9.17 | 0 | 1 | 0 | 0 |
| `org.springframework.boot:spring-boot-starter-actuator` | 2.7.18 | 0 | 1 | 0 | 0 |
| `org.springframework:spring-context` | 5.3.31 | 0 | 0 | 1 | 1 |
| `org.apache.logging.log4j:log4j-api` | 2.17.2 | 0 | 0 | 1 | 0 |
| `org.apache.tomcat.embed:tomcat-embed-websocket` | 9.0.83 | 0 | 0 | 1 | 0 |
| `org.springframework.boot:spring-boot-autoconfigure` | 2.7.18 | 0 | 0 | 1 | 0 |

#### spring-petclinic-2.7.35 (38)

Upgrading to the commercial 2.7.35 release removes every Tomcat and Spring Boot finding, and all Spring Framework findings except one critical in `spring-web`. Most of what's left is in third-party libraries that are still on old lines: Thymeleaf 3.0, Jackson 2.13 and SnakeYAML 1.30.

| Package | Version | C | H | M | L |
|---|---|---:|---:|---:|---:|
| `org.thymeleaf:thymeleaf` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.thymeleaf:thymeleaf-spring5` | 3.0.15.RELEASE | 3 | 0 | 0 | 0 |
| `org.springframework:spring-web` | 5.3.50 | 1 | 0 | 0 | 0 |
| `com.fasterxml.jackson.core:jackson-databind` | 2.13.5 | 0 | 4 | 7 | 0 |
| `com.fasterxml.jackson.core:jackson-core` | 2.13.5 | 0 | 3 | 0 | 0 |
| `org.yaml:snakeyaml` | 1.30 | 0 | 2 | 5 | 0 |
| `com.h2database:h2` | 2.1.214 | 0 | 1 | 0 | 0 |
| `com.mysql:mysql-connector-j` | 8.0.33 | 0 | 1 | 0 | 0 |
| `org.postgresql:postgresql` | 42.3.10 | 0 | 1 | 0 | 0 |
| `ch.qos.logback:logback-core` | 1.2.13 | 0 | 0 | 2 | 4 |
| `org.apache.logging.log4j:log4j-api` | 2.17.2 | 0 | 0 | 1 | 0 |

#### spring-petclinic-3.5.16 (22)

| Package | Version | C | H | M | L |
|---|---|---:|---:|---:|---:|
| `org.apache.tomcat.embed:tomcat-embed-core` | 10.1.55 | 5 | 1 | 1 | 0 |
| `org.springframework:spring-webmvc` | 6.2.19 | 2 | 0 | 0 | 0 |
| `com.fasterxml.jackson.core:jackson-databind` | 2.21.4 | 0 | 3 | 6 | 0 |
| `com.fasterxml.jackson.core:jackson-core` | 2.21.4 | 0 | 2 | 0 | 0 |
| `org.postgresql:postgresql` | 42.7.11 | 0 | 1 | 0 | 0 |
| `org.apache.logging.log4j:log4j-api` | 2.24.3 | 0 | 0 | 1 | 0 |

#### spring-petclinic-3.5.17 (12)

| Package | Version | C | H | M | L | CVEs (fixed in) |
|---|---|---:|---:|---:|---:|---|
| `org.apache.tomcat.embed:tomcat-embed-core` | 10.1.57 | 4 | 0 | 0 | 0 | CVE-2026-65182, -65637, -65905, -68525 (10.1.58 / 10.1.59) |
| `com.fasterxml.jackson.core:jackson-databind` | 2.21.5 | 0 | 3 | 2 | 0 | CVE-2026-68497, -91776, -91777, -19032, -83557 (2.21.6 / 2.21.7) |
| `com.fasterxml.jackson.core:jackson-core` | 2.21.5 | 0 | 2 | 0 | 0 | CVE-2026-89407, -89425 (2.21.7) |
| `org.apache.logging.log4j:log4j-api` | 2.24.3 | 0 | 0 | 1 | 0 | CVE-2026-49844 (2.25.5) |

#### spring-petclinic-3.5.17-patched (1)

| Package | Version | C | H | M | L | CVEs (fixed in) |
|---|---|---:|---:|---:|---:|---|
| `org.apache.logging.log4j:log4j-api` | 2.24.3 | 0 | 0 | 1 | 0 | CVE-2026-49844 (2.25.5) |

#### spring-petclinic-3.5.17-manually-patched (0)

No vulnerabilities found. The manual `log4j2.version=2.25.5` override fixes the last remaining finding.

#### spring-petclinic-4.0.9 (0)

No vulnerabilities found.

#### spring-petclinic-4.1.2 (0)

No vulnerabilities found.

## Takeaways

1. **Staying on an old patch release costs you.** 2.7.3 has 135 findings, 19 of them critical.
2. **The last open-source release isn't enough once open-source support ends.** 2.7.18 still has 121 findings, because Tomcat, Spring Framework and the rest kept getting CVEs after support ended.
3. **Commercial patch releases close most of the gap.** 2.7.35 removes all the Tomcat findings and nearly all the Spring findings, leaving 38, most of them in older third-party libraries.
4. **Keeping up with patch releases on a supported line matters.** 3.5.16 has 22 findings and 3.5.17 has 12.
5. **You can patch dependencies yourself without waiting for a Boot release.** Overriding Tomcat and Jackson takes 3.5.17 down to 1 finding, and also overriding Log4j takes it to 0.
6. **The current generation is clean.** Spring Boot 4.0.9 and 4.1.2 have 0 findings today.

> These counts are a snapshot taken against the trivy DB on the date above. New CVEs are published every day, so re-run `./trivy-scan.sh` before presenting.
