# Changelog

## [1.7.0](https://github.com/esodevops/retail-store-sample-app/compare/v1.6.0...v1.7.0) (2026-06-07)


### Features

* add environment-based OIDC trust for GitHub Actions ([cbbd3bb](https://github.com/esodevops/retail-store-sample-app/commit/cbbd3bbcdfe2285ce42a5b34c85b74832e279151))
* add GitHub Actions workflow for EKS deployment ([12f0d54](https://github.com/esodevops/retail-store-sample-app/commit/12f0d54bba175b22d68a8c6e95109a201d102fd3))
* apply standardized naming conventions for resources ([10300ec](https://github.com/esodevops/retail-store-sample-app/commit/10300ec48cebad182b0eefaf6b7d3a8ca623f2ff))
* apply standardized naming conventions for VPC resources ([0f604b5](https://github.com/esodevops/retail-store-sample-app/commit/0f604b528639623aca8b28aee4f4ab58abb156b5))
* bootstrap OIDC role in Terraform workflow ([16b895c](https://github.com/esodevops/retail-store-sample-app/commit/16b895cbee84c802e78f212408cf17b1979f4132))
* configure local deployment with .env file for AWS credentials ([9adf291](https://github.com/esodevops/retail-store-sample-app/commit/9adf291ecef4e74c5267caa5741fee844a9ddee0))
* configure retail-app namespace for all deployment targets ([be9a905](https://github.com/esodevops/retail-store-sample-app/commit/be9a905e867f0e78154ec817df98d50e0343456e))
* configure retail-app namespace for all deployment targets ([960507b](https://github.com/esodevops/retail-store-sample-app/commit/960507b1ec71ed6fbe0b213564c00a0739fca8c7))
* create GitHub Actions workflow that enables deploying the retail-app directly from GitHub ([aa7c084](https://github.com/esodevops/retail-store-sample-app/commit/aa7c084454860118a08d89112077b10f08c9e90a))
* deploy retail store infra ([510fec2](https://github.com/esodevops/retail-store-sample-app/commit/510fec2950fbaf4465c2db5a2558e51262dc5c4d))
* enable CloudWatch logging permissions for EKS nodes ([470a9c4](https://github.com/esodevops/retail-store-sample-app/commit/470a9c451427c3ee4a4bfaacbcbfcaa66dc953b0))
* grant EKS cluster admin access to deploying user ([64e7f86](https://github.com/esodevops/retail-store-sample-app/commit/64e7f86a3c13aa22a146a2076ebc46e5e5fa4b6e))


### Bug Fixes

* accept role ARN or name and use role.name for IAM policy bindings ([124be98](https://github.com/esodevops/retail-store-sample-app/commit/124be98c9f5ef672ff03ab3470b5be59d075fe38))
* accept role ARN or name for IAM role inputs ([3e6e8fe](https://github.com/esodevops/retail-store-sample-app/commit/3e6e8fe87134766ac9338d002ebada9b0033070b))
* Add comprehensive resource imports to handle existing AWS resources ([cb8ed73](https://github.com/esodevops/retail-store-sample-app/commit/cb8ed738686b6bd8acf715629dad7df1deb202b5))
* add debug step to verify Terraform installation in deploy workflow ([5abd667](https://github.com/esodevops/retail-store-sample-app/commit/5abd667731abe9544be6092d70dd2767d192f435))
* add EKS cluster access for GitHub Actions role ([d8d9351](https://github.com/esodevops/retail-store-sample-app/commit/d8d935167499c38b7a84f0f7c0d83fd72c012d25))
* add grading output mode ([070d027](https://github.com/esodevops/retail-store-sample-app/commit/070d027cef45e441321536f00639432c38da2384))
* add Terraform, kubectl, and Helm setup steps to deploy workflow ([bb96b00](https://github.com/esodevops/retail-store-sample-app/commit/bb96b00107b1216144111845ec9673bf5c0de327))
* correct ingress resource name in deployment workflow ([b5cda12](https://github.com/esodevops/retail-store-sample-app/commit/b5cda12d756e25b43953db6387a1109a602fe4db))
* correct the OIDC for already existing role ([80995c2](https://github.com/esodevops/retail-store-sample-app/commit/80995c2fb6325444ccbbe813bf6d4a3e8acc31ed))
* downgrade the ec2 instance type ([80f4e41](https://github.com/esodevops/retail-store-sample-app/commit/80f4e41fe7a64774b503fe51383c3c93fae23af3))
* enable force_destroy for S3 state bucket ([8fcb9ed](https://github.com/esodevops/retail-store-sample-app/commit/8fcb9ed543080af9e13ac2da7987ad3a1569f2f2))
* enable force_destroy for S3 state bucket ([9031dce](https://github.com/esodevops/retail-store-sample-app/commit/9031dce53de5ad7bd318d54e8a2c64ed75a12892))
* force cleanup EKS access entry before apply ([775c455](https://github.com/esodevops/retail-store-sample-app/commit/775c455e4cdea19863b45de46eed12342f942f6d))
* import EKS access entries before deploy ([7f73eff](https://github.com/esodevops/retail-store-sample-app/commit/7f73eff406dfa49ea6b116f8b91e337b7d0ac8a7))
* improve AWS Load Balancer Controller configuration and add debugging ([e8618a3](https://github.com/esodevops/retail-store-sample-app/commit/e8618a3781cc455c546e7c0b7b9a36f84cad6471))
* improve OIDC provider creation ([29f2c1c](https://github.com/esodevops/retail-store-sample-app/commit/29f2c1cdc3797a9d86be000dccf5c3377892602a))
* improve OIDC provider creation in setup script ([f1514e8](https://github.com/esodevops/retail-store-sample-app/commit/f1514e89be9c3bb57f7fb92daadcb36d5f1d6717))
* keep developer console password active ([9125c1a](https://github.com/esodevops/retail-store-sample-app/commit/9125c1a5e797c2e066527a262e3377ed16e23c18))
* make OIDC provider setup idempotent ([9083458](https://github.com/esodevops/retail-store-sample-app/commit/90834589f66039e252ec31c41db72fe26f5b0152))
* OIDC bootstrap role resolution ([9ae9996](https://github.com/esodevops/retail-store-sample-app/commit/9ae9996eb864c169bf9b11ade1e1dee54a6802fb))
* remove redundant deployer EKS access entry ([a7c931f](https://github.com/esodevops/retail-store-sample-app/commit/a7c931fa1df20bef62630cc6c8967ec7b6835643))
* remove the grading.json from the pipeline ([3a734de](https://github.com/esodevops/retail-store-sample-app/commit/3a734def8fefd7a10d1c110134698ac07843a557))
* repair OIDC provider bootstrap flow ([9303adb](https://github.com/esodevops/retail-store-sample-app/commit/9303adbf77d89f83dfcb039ca186ca1929261d8a))
* resolve GitHub Actions OIDC authentication errors ([cb2dbf2](https://github.com/esodevops/retail-store-sample-app/commit/cb2dbf260da8c822387f9163d781410bc621188e))
* sanitize IAM role names for Terraform resources ([d3452d1](https://github.com/esodevops/retail-store-sample-app/commit/d3452d1466eef9ae6d2d001fd231d75c4750e80e))
* skip deployer access entry when already exists ([e6b8d60](https://github.com/esodevops/retail-store-sample-app/commit/e6b8d606279344af0814da025460cad90b1be99b))
* skip deployer access entry when already exists ([e2256b9](https://github.com/esodevops/retail-store-sample-app/commit/e2256b91c93f43012e3c0e989a3be7c61b2e3acc))
* update cleanup script and the grading.json file from redacted to open file ([6f2523e](https://github.com/esodevops/retail-store-sample-app/commit/6f2523e9594492058758b0b17fa9968530677875))
* update helm chart and cleanup script ([8cca9f0](https://github.com/esodevops/retail-store-sample-app/commit/8cca9f0bbe3a1ff0bf2d86fe20ce9e1531570291))
* update helm chart to take any aws profile for deployment ([a9cd4d8](https://github.com/esodevops/retail-store-sample-app/commit/a9cd4d8d39937d8d65659e8c1a0b2c09a65de13d))
* update helm deployment chart through GitHub Actions ([11e6c98](https://github.com/esodevops/retail-store-sample-app/commit/11e6c983c943822bb0e0bcbdb7c37a56a4cbe2d0))
* update OIDC configuration to import secret properly ([65c79cb](https://github.com/esodevops/retail-store-sample-app/commit/65c79cbbadce22f7d7b7b3071ee1a94f79f36449))
* update OIDC setup ([86e0a85](https://github.com/esodevops/retail-store-sample-app/commit/86e0a85877972d0f35de75d6fe4d486d234b9865))
* update OIDC setup ([f01e9d7](https://github.com/esodevops/retail-store-sample-app/commit/f01e9d7e08337c59529801fc0ef7a028ee763dfb))
* update terraform and cleanup files ([4dbf5b8](https://github.com/esodevops/retail-store-sample-app/commit/4dbf5b81cb2927054af5a5f0a5d58b9b011648e1))
* update terraform and cleanup script ([3f48850](https://github.com/esodevops/retail-store-sample-app/commit/3f48850bac835af135462290be17f5d329f8c602))
* update terraform for resources naming uniqueness ([b76cf13](https://github.com/esodevops/retail-store-sample-app/commit/b76cf13e47f576c7b8ffd9914f338219f2763527))
* update terraform to resolve naming convention issue ([c488340](https://github.com/esodevops/retail-store-sample-app/commit/c488340f17cb61f0aefd65658a534e912b02b3b3))
* update the OIDC connection error ([c15a65d](https://github.com/esodevops/retail-store-sample-app/commit/c15a65d52dc497aba52b8cfd62934c94d874ea7a))
* update the resources naming pattern, terraform and github action ([10ae59f](https://github.com/esodevops/retail-store-sample-app/commit/10ae59f5a6a0fd51974e4d19a1cac205f47404e1))
* upgrade Terraform to v1.9.0 to resolve expired OpenPGP key error ([751c673](https://github.com/esodevops/retail-store-sample-app/commit/751c67302a6960942fe6eeee3e44cd751dd95e0d))
* use existing IRSA service account for AWS Load Balancer Controller ([69c1151](https://github.com/esodevops/retail-store-sample-app/commit/69c1151c3aca66ff9a0b07d53f50f856d2e99feb))

## [1.6.0](https://github.com/esodevops/retail-store-sample-app/compare/v1.5.0...v1.6.0) (2026-06-01)


### Features

* harden cleanup, workflows, and k8s ingress deployment ([3999e2c](https://github.com/esodevops/retail-store-sample-app/commit/3999e2c387fbc0e416f9833087ad55c4ea199b77))
* harden cleanup, workflows, and k8s ingress deployment ([395a5c9](https://github.com/esodevops/retail-store-sample-app/commit/395a5c9b4a0368bff4d10d6e718f0350434a0f70))


### Bug Fixes

* add clean up script ([726b103](https://github.com/esodevops/retail-store-sample-app/commit/726b1036af3752a8933dc2343b8a28d270257908))
* add clean up script ([70a68f5](https://github.com/esodevops/retail-store-sample-app/commit/70a68f56831a8e4b497e677a58a027e626a7a326))
* handle us-east-1 S3 bucket creation for Terraform state ([d94ca16](https://github.com/esodevops/retail-store-sample-app/commit/d94ca1620d26ff9ca3f7888c6eda4c1396549e99))

## [1.5.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.4.2...v1.5.0) (2026-04-29)


### Features

* UI text response ([#1017](https://github.com/aws-containers/retail-store-sample-app/issues/1017)) ([5ad97e0](https://github.com/aws-containers/retail-store-sample-app/commit/5ad97e0be1d3d4a3f58bd13fcaf82dd86fca9238))


### Bug Fixes

* **deps:** update module go.opentelemetry.io/otel to v1.41.0 [security] ([#1023](https://github.com/aws-containers/retail-store-sample-app/issues/1023)) ([2a36bed](https://github.com/aws-containers/retail-store-sample-app/commit/2a36bed47dd665300288c4a3ed856dc7cd8a0fe3))
* **deps:** update module go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp to v1.43.0 [security] ([#1004](https://github.com/aws-containers/retail-store-sample-app/issues/1004)) ([5c55137](https://github.com/aws-containers/retail-store-sample-app/commit/5c55137a0af2750235cf827b539acc4e67f73e04))
* Fix Spring Boot 3 http codec setting ([f8f494a](https://github.com/aws-containers/retail-store-sample-app/commit/f8f494afc52051426fc0b318ef17a4a8c35b7d96))
* Remove console print in UI ([560f9dd](https://github.com/aws-containers/retail-store-sample-app/commit/560f9dd9f467dab44cf18a8251b3676b16a2c305))

## [1.4.2](https://github.com/aws-containers/retail-store-sample-app/compare/v1.4.1...v1.4.2) (2026-04-15)


### Bug Fixes

* retry MySQL connection on startup ([#1005](https://github.com/aws-containers/retail-store-sample-app/issues/1005)) ([014320e](https://github.com/aws-containers/retail-store-sample-app/commit/014320e36eabc49607d03f7c1291c49e0684999f))
* Update catalog goproxy ([#1009](https://github.com/aws-containers/retail-store-sample-app/issues/1009)) ([44244b0](https://github.com/aws-containers/retail-store-sample-app/commit/44244b07eb2e132dbb6caeaeaec43b0119f0db8c))

## [1.4.1](https://github.com/aws-containers/retail-store-sample-app/compare/v1.4.0...v1.4.1) (2026-04-06)


### Bug Fixes

* **orders:** Align field for address between checkout & orders ([#969](https://github.com/aws-containers/retail-store-sample-app/issues/969)) ([4881987](https://github.com/aws-containers/retail-store-sample-app/commit/4881987baef829774c6dc56dd8d8d03a0f279e1a))

## [1.4.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.3.0...v1.4.0) (2026-01-30)


### Features

* Support redis TLS for checkout service ([#943](https://github.com/aws-containers/retail-store-sample-app/issues/943)) ([d587fb8](https://github.com/aws-containers/retail-store-sample-app/commit/d587fb80954b5666dd0f9b0b7b48199df7a33dd0))


### Bug Fixes

* Set shipping informations in checkout ([#951](https://github.com/aws-containers/retail-store-sample-app/issues/951)) ([457407b](https://github.com/aws-containers/retail-store-sample-app/commit/457407bf585578051d5959a1928d86fc7dc32f07))

## [1.3.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.4...v1.3.0) (2025-09-16)


### Features

* Add EventBridge lifecycle events for ECS Container Insights and update ADOT to CloudWatch Agent ([#913](https://github.com/aws-containers/retail-store-sample-app/issues/913)) ([549594b](https://github.com/aws-containers/retail-store-sample-app/commit/549594bf1f47d16f19a02ce040b55e4353dd8be6))


### Bug Fixes

* Add UI teal theme color ([#923](https://github.com/aws-containers/retail-store-sample-app/issues/923)) ([b382620](https://github.com/aws-containers/retail-store-sample-app/commit/b382620fcc7753b0e9c5256e972bc0844e8d9039))
* **deps:** update dependency org.openapitools:jackson-databind-nullable to v0.2.7 ([#926](https://github.com/aws-containers/retail-store-sample-app/issues/926)) ([46849a7](https://github.com/aws-containers/retail-store-sample-app/commit/46849a74089f06acad31222b6c4d7cdb8da32984))
* **deps:** update dependency org.projectlombok:lombok to v1.18.40 ([#927](https://github.com/aws-containers/retail-store-sample-app/issues/927)) ([4544834](https://github.com/aws-containers/retail-store-sample-app/commit/454483476947cc4e911f707969fdb898b4e9ae62))
* **deps:** update dependency org.springframework.ai:spring-ai-bom to v1.0.2 ([#928](https://github.com/aws-containers/retail-store-sample-app/issues/928)) ([948ce82](https://github.com/aws-containers/retail-store-sample-app/commit/948ce82b2192135ca5c69bb4582011f176dbda1b))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.5.5 ([#929](https://github.com/aws-containers/retail-store-sample-app/issues/929)) ([72fa4e8](https://github.com/aws-containers/retail-store-sample-app/commit/72fa4e8f15253cce61c15657d0a396d3c95d5b50))
* **deps:** update kiota to v1.8.10 ([#930](https://github.com/aws-containers/retail-store-sample-app/issues/930)) ([a1012bf](https://github.com/aws-containers/retail-store-sample-app/commit/a1012bf29c862c4e91acf4fbd2547e62af95132a))
* Improved CW Logging for ECS default deployment ([#921](https://github.com/aws-containers/retail-store-sample-app/issues/921)) ([eff0668](https://github.com/aws-containers/retail-store-sample-app/commit/eff06680c3639acda4d878a2f01d68216955be95))
* Revert Spring AI to 1.0.0 ([0a9994b](https://github.com/aws-containers/retail-store-sample-app/commit/0a9994b447e0e5e44c092eb0d5b4940bbe829e62))
* wait for VPC resource controller before deploying workloads ([#914](https://github.com/aws-containers/retail-store-sample-app/issues/914)) ([902302a](https://github.com/aws-containers/retail-store-sample-app/commit/902302a84aa52f9a0a84f8b807d7918deccee6d4))

## [1.2.4](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.3...v1.2.4) (2025-08-13)


### Bug Fixes

* Fix load generator not completing orders ([#915](https://github.com/aws-containers/retail-store-sample-app/issues/915)) ([c43a8bb](https://github.com/aws-containers/retail-store-sample-app/commit/c43a8bb753008b860b59c795622e3e327233c398))

## [1.2.3](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.2...v1.2.3) (2025-08-01)


### Bug Fixes

* Consistent OpenTelemetry versions in Java components ([5ea06b9](https://github.com/aws-containers/retail-store-sample-app/commit/5ea06b9900d2d4878f560673c3664cb1386d7fb9))
* **deps:** update dependency software.amazon.awssdk:bom to v2.32.13 ([#884](https://github.com/aws-containers/retail-store-sample-app/issues/884)) ([ebe9760](https://github.com/aws-containers/retail-store-sample-app/commit/ebe9760c6bda84e83dd38544384d30bc6d3ea9c9))
* **deps:** update kiota to v1.8.8 ([#885](https://github.com/aws-containers/retail-store-sample-app/issues/885)) ([393fb36](https://github.com/aws-containers/retail-store-sample-app/commit/393fb3697e3ca9dc67bb3d95b72e3e38b41f95b7))
* Use correct RabbitMQ credential field names ([#911](https://github.com/aws-containers/retail-store-sample-app/issues/911)) ([2bbedc1](https://github.com/aws-containers/retail-store-sample-app/commit/2bbedc12863ec36bec65598d6f64b259530517f9))

## [1.2.2](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.1...v1.2.2) (2025-07-14)


### Bug Fixes

* **deps:** update dependency axios to v1.10.0 ([#874](https://github.com/aws-containers/retail-store-sample-app/issues/874)) ([4c0113e](https://github.com/aws-containers/retail-store-sample-app/commit/4c0113e8144252a068b199a7c00c0924ac52fb90))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.5.3 ([#879](https://github.com/aws-containers/retail-store-sample-app/issues/879)) ([08120b1](https://github.com/aws-containers/retail-store-sample-app/commit/08120b10d311d5b30bbf3b30f7a80537ec61b912))
* Remove catalog in-memory db logging ([#880](https://github.com/aws-containers/retail-store-sample-app/issues/880)) ([83ca5dd](https://github.com/aws-containers/retail-store-sample-app/commit/83ca5dd7f7c30c4b752d9feca12f14a18b93f231))

## [1.2.1](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.0...v1.2.1) (2025-07-03)


### Bug Fixes

* **deps:** update dependency software.amazon.awssdk:bom to v2.31.76 ([#857](https://github.com/aws-containers/retail-store-sample-app/issues/857)) ([9565e5e](https://github.com/aws-containers/retail-store-sample-app/commit/9565e5e386c4c7e6863c1691c70d6f6151901152))
* **deps:** update kiota to v1.8.7 ([#854](https://github.com/aws-containers/retail-store-sample-app/issues/854)) ([726ba0b](https://github.com/aws-containers/retail-store-sample-app/commit/726ba0b484fed0573aaf76b0c13ead590f24ebdd))
* **deps:** update module github.com/gin-gonic/gin to v1.10.1 ([#855](https://github.com/aws-containers/retail-store-sample-app/issues/855)) ([e81b40e](https://github.com/aws-containers/retail-store-sample-app/commit/e81b40e88c1286c86f705b68f1b4b16995a24cd7))
* **deps:** update opentelemetry-go monorepo to v1.37.0 ([#819](https://github.com/aws-containers/retail-store-sample-app/issues/819)) ([5312383](https://github.com/aws-containers/retail-store-sample-app/commit/531238309930200fdd1dd58200619c91d56a7f6e))
* UI mock catalog tag filters ([114b3c9](https://github.com/aws-containers/retail-store-sample-app/commit/114b3c9584c7ac49be19868ce33e2c51b5f17916))

## [1.2.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.1.0...v1.2.0) (2025-07-02)


### Features

* Allow serving sample images from filesystem ([#853](https://github.com/aws-containers/retail-store-sample-app/issues/853)) ([43f3283](https://github.com/aws-containers/retail-store-sample-app/commit/43f3283f84ad0db99f75fa05e7eb7130c56d149e))
* Optimize asset image sizes ([#840](https://github.com/aws-containers/retail-store-sample-app/issues/840)) ([65a7748](https://github.com/aws-containers/retail-store-sample-app/commit/65a7748dfd99a1392baf788d2a059228a35062ce))
* Upgraded checkout to NestJS v11 ([#842](https://github.com/aws-containers/retail-store-sample-app/issues/842)) ([4f1c921](https://github.com/aws-containers/retail-store-sample-app/commit/4f1c921320061e6e7716a14409fa3c640c98a917))


### Bug Fixes

* **deps:** bump golang.org/x/crypto in /src/catalog ([#829](https://github.com/aws-containers/retail-store-sample-app/issues/829)) ([50ff85c](https://github.com/aws-containers/retail-store-sample-app/commit/50ff85c654aa7f4c4469d8fb27a28c2c96988214))
* **deps:** bump golang.org/x/net from 0.34.0 to 0.38.0 in /src/catalog ([#831](https://github.com/aws-containers/retail-store-sample-app/issues/831)) ([6303846](https://github.com/aws-containers/retail-store-sample-app/commit/63038463f862f2d18518c17b72355f53cf5b173c))
* **deps:** update dependency io.opentelemetry.instrumentation:opentelemetry-instrumentation-bom to v2.17.0 ([#811](https://github.com/aws-containers/retail-store-sample-app/issues/811)) ([7ee50f7](https://github.com/aws-containers/retail-store-sample-app/commit/7ee50f71c86fe8bf27f5b7d3651e44d59c11086a))
* **deps:** update dependency io.swagger:swagger-annotations to v1.6.16 ([#849](https://github.com/aws-containers/retail-store-sample-app/issues/849)) ([17b44b6](https://github.com/aws-containers/retail-store-sample-app/commit/17b44b655bdd8011bc65d38301b720588042ead2))
* **deps:** update dependency org.projectlombok:lombok to v1.18.38 ([#850](https://github.com/aws-containers/retail-store-sample-app/issues/850)) ([2f76853](https://github.com/aws-containers/retail-store-sample-app/commit/2f768538e9ad409dba0ae4b1b83f76e3b0aed8b0))
* **deps:** update dependency org.springdoc:springdoc-openapi-starter-webmvc-ui to v2.8.9 ([#851](https://github.com/aws-containers/retail-store-sample-app/issues/851)) ([4a1a201](https://github.com/aws-containers/retail-store-sample-app/commit/4a1a2014222dd549850352f78851646830693143))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.75 ([#852](https://github.com/aws-containers/retail-store-sample-app/issues/852)) ([3229234](https://github.com/aws-containers/retail-store-sample-app/commit/32292347ae4b7ffd2172e4b17ef5210966527d64))
* UI chart should only set theme if configured ([88ec5cd](https://github.com/aws-containers/retail-store-sample-app/commit/88ec5cd95722d5e164ddafdc1eb230d233667c4f))

## [1.1.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.2...v1.1.0) (2025-03-23)


### Features

* Chaos testing endpoints ([#818](https://github.com/aws-containers/retail-store-sample-app/issues/818)) ([f8f2207](https://github.com/aws-containers/retail-store-sample-app/commit/f8f22078ea67049144bc2d59efc7a60c730c67f0))


### Bug Fixes

* **deps:** update dependency axios to v1.8.4 ([#791](https://github.com/aws-containers/retail-store-sample-app/issues/791)) ([06fe506](https://github.com/aws-containers/retail-store-sample-app/commit/06fe506a860bdadbe7fa69251b87ff62878f7f5d))
* **deps:** update dependency de.codecentric:chaos-monkey-spring-boot to v3.1.4 ([#769](https://github.com/aws-containers/retail-store-sample-app/issues/769)) ([8aeeea4](https://github.com/aws-containers/retail-store-sample-app/commit/8aeeea4ec3bbd6ec93c3a13aea43d15d805c0c3c))
* **deps:** update dependency de.codecentric:chaos-monkey-spring-boot to v3.2.0 ([#810](https://github.com/aws-containers/retail-store-sample-app/issues/810)) ([aff5aa9](https://github.com/aws-containers/retail-store-sample-app/commit/aff5aa94a81923765d38f3a4dd7b639706be1563))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.4.4 ([#802](https://github.com/aws-containers/retail-store-sample-app/issues/802)) ([3a9b53f](https://github.com/aws-containers/retail-store-sample-app/commit/3a9b53f1a1387ea0bfeabd7d6495983f15922ac3))
* **deps:** update dependency org.springframework.cloud:spring-cloud-gateway-webflux to v4.2.1 ([#798](https://github.com/aws-containers/retail-store-sample-app/issues/798)) ([0506dac](https://github.com/aws-containers/retail-store-sample-app/commit/0506dac93cb109d12665c418b3412db3d2eca53b))
* **deps:** update dependency reflect-metadata to ^0.2.0 ([#813](https://github.com/aws-containers/retail-store-sample-app/issues/813)) ([4b67fc5](https://github.com/aws-containers/retail-store-sample-app/commit/4b67fc57514596585c7d4aa5d75042f6a6dd95ba))
* **deps:** update dependency rxjs to v7.8.2 ([#772](https://github.com/aws-containers/retail-store-sample-app/issues/772)) ([04d1b3c](https://github.com/aws-containers/retail-store-sample-app/commit/04d1b3c3a7e0a75252ec26d99c5ca488e84b7fbe))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.5 ([#793](https://github.com/aws-containers/retail-store-sample-app/issues/793)) ([83365cb](https://github.com/aws-containers/retail-store-sample-app/commit/83365cb236b055a61d559896e27ffec7478e7169))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.6 ([#815](https://github.com/aws-containers/retail-store-sample-app/issues/815)) ([40f9e98](https://github.com/aws-containers/retail-store-sample-app/commit/40f9e98af9395dabb2278f5f6f246caa7cf5b413))
* **deps:** update module gorm.io/plugin/opentelemetry to v0.1.12 ([#799](https://github.com/aws-containers/retail-store-sample-app/issues/799)) ([b04eb5f](https://github.com/aws-containers/retail-store-sample-app/commit/b04eb5f984ea6c408165e988f7f25c80da9d2b85))

## [1.0.2](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.1...v1.0.2) (2025-03-20)


### Bug Fixes

* Expose UI chat configuration in chart ([58597cc](https://github.com/aws-containers/retail-store-sample-app/commit/58597cc9206758f95cf50f6b37df02fa828059d1))

## [1.0.1](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.0...v1.0.1) (2025-03-13)


### Bug Fixes

* safely remove cart items ([#752](https://github.com/aws-containers/retail-store-sample-app/issues/752)) ([c766bd3](https://github.com/aws-containers/retail-store-sample-app/commit/c766bd3a9f2b24395f3a1276e0a1bc9fc7804f0d))

## 1.0.0 (2025-02-28)


### Features

* Add headers, panic, echo and store utilities ([#728](https://github.com/aws-containers/retail-store-sample-app/issues/728)) ([c4f703b](https://github.com/aws-containers/retail-store-sample-app/commit/c4f703bc78bd832116a78e78bf44024aa5c361ca))
* Application v1 ([#742](https://github.com/aws-containers/retail-store-sample-app/issues/742)) ([2ea99fb](https://github.com/aws-containers/retail-store-sample-app/commit/2ea99fbf94c891c4da166c2527f082ab5c621240))
