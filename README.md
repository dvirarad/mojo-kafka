<div align="center">

# mojo-kafka

**Apache Kafka client for [Mojo🔥](https://www.modular.com/mojo) — backed by [`librdkafka`](https://github.com/confluentinc/librdkafka).**

Stream Kafka straight into your Mojo / MAX inference loop. No Python hop, no GIL on the hot path.

[![CI](https://github.com/dvirarad/mojo-kafka/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dvirarad/mojo-kafka/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dvirarad/mojo-kafka?include_prereleases&sort=semver&label=release)](https://github.com/dvirarad/mojo-kafka/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Mojo](https://img.shields.io/badge/Mojo-%E2%89%A524.6-orange)](https://docs.modular.com/mojo/)
[![librdkafka](https://img.shields.io/badge/librdkafka-%E2%89%A52.3-red)](https://github.com/confluentinc/librdkafka)
[![Status](https://img.shields.io/badge/status-alpha-yellow)](#status)

</div>

---

## Why this exists

Mojo's pitch is *"Python ergonomics, systems performance, AI-native."* The place that pitch meets the real world is the **data pipeline** — and most ML pipelines today drink from Kafka.

If you want a Kafka topic feeding a Mojo model today, your options are:

1. **Hop through Python** with `confluent-kafka-python` — every message pays a Python ↔ Mojo FFI tax, plus you're back in GIL territory.
2. **Hand-roll `librdkafka` bindings** yourself — possible, but it's a lot of opaque pointers and struct offsets.

`mojo-kafka` is **option 3**: a Mojo-idiomatic, Pythonic API over the same `librdkafka` C foundation that every non-JVM Kafka client (Go, Rust, Python, Node, .NET) is already built on. Familiar shape, native perf, no FFI tax per message.

```mojo
from kafka import Consumer, ConsumerConfig

fn main() raises:
    var c = Consumer(ConsumerConfig(
        bootstrap_servers="localhost:9092",
        group_id="mojo-ml-trainer",
        auto_offset_reset="earliest",
    ))
    c.subscribe(["embeddings"])
    while True:
        var msg = c.poll(timeout_ms=1000)
        if msg:
            run_inference(msg.value)    # straight into your Mojo / MAX model
    c.close()
```

## Install

`mojo-kafka` depends on `librdkafka` at runtime. Recommended: let `pixi` handle everything.

```toml
# pixi.toml
[workspace]
channels = ["https://conda.modular.com/max", "conda-forge"]
platforms = ["linux-64", "osx-arm64"]

[dependencies]
max = ">=24.6"
librdkafka = ">=2.3.0"
```

Then add `mojo-kafka` as a Mojo dependency (vendor the package, or pull `src/kafka/` into your tree — it's small and dependency-free on the Mojo side):

```bash
git clone https://github.com/dvirarad/mojo-kafka.git
cp -r mojo-kafka/src/kafka your_project/src/
```

Prefer system packages? `librdkafka` is widely available:

```bash
brew install librdkafka                 # macOS
sudo apt install librdkafka-dev         # Debian / Ubuntu
sudo dnf install librdkafka-devel       # Fedora
```

## Quickstart

### Produce

```mojo
from kafka import Producer, ProducerConfig

fn main() raises:
    var p = Producer(ProducerConfig(bootstrap_servers="localhost:9092"))
    p.produce(topic="events", key="user-42", value="login")
    p.flush(timeout_ms=5000)
```

### Consume

```mojo
from kafka import Consumer, ConsumerConfig

fn main() raises:
    var c = Consumer(ConsumerConfig(
        bootstrap_servers="localhost:9092",
        group_id="my-app",
        auto_offset_reset="earliest",
    ))
    c.subscribe(["events"])
    for _ in range(100):
        var msg = c.poll(1000)
        if msg:
            print(msg.partition, msg.offset, msg.key, msg.value)
    c.close()
```

### Admin

```mojo
from kafka import AdminClient

fn main() raises:
    var admin = AdminClient(bootstrap_servers="localhost:9092")
    admin.create_topic("events", num_partitions=3, replication_factor=1)
    for t in admin.list_topics():
        print(t)
```

See [`examples/`](examples/) for runnable scripts, including [`examples/ml_pipeline.mojo`](examples/ml_pipeline.mojo) — a streaming feature pipeline that reads events off Kafka and feeds them into a tensor.

## API surface (v0.1)

| Symbol | What it does |
|---|---|
| `Producer` / `ProducerConfig` | Produce messages; `flush()` / `poll()` for delivery |
| `Consumer` / `ConsumerConfig` | Subscribe, poll for messages, commit offsets, close |
| `AdminClient` | Create / list topics |
| `Message` | `partition`, `offset`, `key`, `value` (full `topic` + `headers` on the v0.2 roadmap) |
| `KafkaError` | Raised with `librdkafka` error code + human description |

The full configuration surface mirrors `librdkafka` — under-the-hood, `ProducerConfig` / `ConsumerConfig` translate snake_case fields into the canonical `librdkafka` property names (`bootstrap.servers`, `auto.offset.reset`, …), so anything the C client supports is reachable.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  your Mojo / MAX code                               │
│                                                     │
│  from kafka import Producer, Consumer, AdminClient  │
└────────────────────┬────────────────────────────────┘
                     │  Pythonic Mojo API
┌────────────────────▼────────────────────────────────┐
│  src/kafka/{producer,consumer,admin,config}.mojo    │
│  typed structs, lifetime management, error mapping  │
└────────────────────┬────────────────────────────────┘
                     │  external_call[...]
┌────────────────────▼────────────────────────────────┐
│  src/kafka/_ffi.mojo                                │
│  raw librdkafka symbol declarations                 │
└────────────────────┬────────────────────────────────┘
                     │  C ABI
┌────────────────────▼────────────────────────────────┐
│  librdkafka.so / .dylib    (BSD-2-Clause, dynamic)  │
└─────────────────────────────────────────────────────┘
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the longer write-up on FFI lifetimes and the C handle story.

## Status

**Alpha.** `v0.1.0` is the first public release. The FFI layer binds real `librdkafka` symbols, smoke tests pass, and the integration test runs against `apache/kafka:3.7.0` in CI. Expect:

- API shape may still shift in `v0.2`.
- A few rough edges are tracked as [`good first issue`](https://github.com/dvirarad/mojo-kafka/labels/good%20first%20issue) — including [exposing `Message.topic`](https://github.com/dvirarad/mojo-kafka/issues/1), [headers](https://github.com/dvirarad/mojo-kafka/issues/2), [a typed `KafkaErrorKind`](https://github.com/dvirarad/mojo-kafka/issues/3), and the [transactional producer](https://github.com/dvirarad/mojo-kafka/issues/4).

Use it in spikes and prototypes today. Wait for `v1.0` before betting a production pipeline.

## Roadmap

- **v0.2** — `Message.topic`, headers, typed `KafkaErrorKind`, async `consume()` generator.
- **v0.3** — Transactional producer, exactly-once semantics, Schema Registry helpers (Avro / Protobuf).
- **v0.4** — Tensor-zero-copy (`Message.value` as `UnsafePointer`) so MAX tensors can wrap incoming bytes without a copy.
- **v1.0** — API stable; production-ready feature parity with `confluent-kafka-python`.

Feature requests go in the [issue tracker](https://github.com/dvirarad/mojo-kafka/issues). Comment with a 👍 to vote.

## Contributing

We protect `main` — contributions land via PR with passing CI and a review from a maintainer. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide, but the short version is:

1. Fork & branch.
2. `pixi install`
3. Make your change; add a test in `tests/` if behavior changes.
4. `pixi run lint && pixi run test`
5. Open a PR. CI must be green.

Interesting layers if you're new:

- [`src/kafka/_ffi.mojo`](src/kafka/_ffi.mojo) — raw `librdkafka` symbol declarations.
- [`src/kafka/config.mojo`](src/kafka/config.mojo) — typed config builder over `rd_kafka_conf_t`.
- [`src/kafka/{producer,consumer,admin}.mojo`](src/kafka/) — public API.

Security issues? See [`SECURITY.md`](SECURITY.md) — please **don't** open a public issue for a CVE-shaped thing.

## License

Apache 2.0 — see [`LICENSE`](LICENSE). `librdkafka` itself is BSD-2-Clause and is dynamically linked, not bundled or redistributed.

## Acknowledgments

- Confluent's [`librdkafka`](https://github.com/confluentinc/librdkafka) — the C client this whole project stands on.
- [`confluent-kafka-python`](https://github.com/confluentinc/confluent-kafka-python) — API shape we tried to honor.
- The Modular team, for [Mojo🔥](https://www.modular.com/mojo) and a C FFI that makes wrappers like this possible.
