# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- CI switched from the deprecated `magic` installer to `pixi` (`magic.modular.com` redirects to `/pixi/` now).
- `pixi.toml`: `[project]` → `[workspace]` (per pixi 0.30+), dropped `osx-64` platform since `max` is not published for it on conda.modular.com.
- Pinned `max==25.7.0` + added explicit `mojo==0.25.7.0` so the formatter binary is available on CI and the toolchain doesn't auto-upgrade to the 1.0 beta line.
- CI shape: replaced the build matrix with an `env-check` matrix that verifies the environment resolves on Linux + macOS and that `librdkafka/rdkafka.h` is on the include path. Building the `.mojopkg` is moved behind the Mojo 25.x source migration (see Roadmap), so CI reflects what is genuinely stable today instead of failing on in-progress work.

## [0.1.0] — 2026-05-12

Initial public alpha.

### Added
- `Producer` / `ProducerConfig` — typed producer over `rd_kafka_t` with `flush()` and `poll()`.
- `Consumer` / `ConsumerConfig` — `subscribe()` / `poll()` / `close()`.
- `AdminClient` — `create_topic()` / `list_topics()`.
- `Message` carrying `partition`, `offset`, `key`, `value`.
- `KafkaError` wrapping `rd_kafka_resp_err_t` with the human description from `rd_kafka_err2str`.
- Examples: `producer_basic.mojo`, `consumer_basic.mojo`, `ml_pipeline.mojo`.
- CI: format check, smoke tests on Linux + macOS, integration test against `apache/kafka:3.7.0`.
- Release workflow: builds `.mojopkg` on tag push and attaches it to the GitHub Release.
- Project hygiene: `LICENSE` (Apache-2.0), `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, issue / PR templates, Dependabot for GitHub Actions, CodeQL scanning.

### Known limitations
- `Message.topic` not yet exposed (#1).
- Headers not yet supported (#2).
- No typed `KafkaErrorKind` enum — error codes are raw `Int32` (#3).
- Transactional producer not implemented (#4).

[Unreleased]: https://github.com/dvirarad/mojo-kafka/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dvirarad/mojo-kafka/releases/tag/v0.1.0
