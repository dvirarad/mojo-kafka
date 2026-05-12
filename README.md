# mojo-kafka

> Apache Kafka client for [Mojo](https://www.modular.com/mojo) — `librdkafka` bindings with a Pythonic producer / consumer / admin API. Stream Kafka straight into your Mojo ML pipelines.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Mojo](https://img.shields.io/badge/Mojo-%E2%89%A524.6-orange)](https://docs.modular.com/mojo/)
[![Status](https://img.shields.io/badge/status-alpha-yellow)](#project-status)

## Why

Mojo's pitch is *"Python ergonomics, systems performance, AI-native"*. The natural place this collides with the real world is the data pipeline — and most ML data pipelines live on Kafka. Today, if you want to consume a Kafka topic from Mojo you have to:

1. Drop down to Python and use `confluent-kafka-python`, losing Mojo's perf advantage on the hot path.
2. Wrap `librdkafka` yourself through Mojo's C FFI — possible, but tedious.

`mojo-kafka` is option (3): a thin, well-typed Mojo wrapper over `librdkafka` so you can produce / consume / admin from Mojo directly.

```mojo
from kafka import Consumer, ConsumerConfig

fn main() raises:
    var cfg = ConsumerConfig(
        bootstrap_servers="localhost:9092",
        group_id="mojo-ml-trainer",
        auto_offset_reset="earliest",
    )
    var consumer = Consumer(cfg)
    consumer.subscribe(["embeddings"])

    while True:
        var msg = consumer.poll(timeout_ms=1000)
        if msg:
            # hand the raw bytes straight to a tensor on the GPU
            run_inference(msg.value)
```

## Install

`mojo-kafka` is a thin wrapper, so you need `librdkafka` available at runtime.

```bash
# macOS
brew install librdkafka

# Debian / Ubuntu
sudo apt install librdkafka-dev

# Fedora
sudo dnf install librdkafka-devel
```

Then add it as a dependency in your Mojo project:

```toml
# pixi.toml
[dependencies]
mojo-kafka = { git = "https://github.com/dvirarad/mojo-kafka", branch = "main" }
```

Or vendor `src/kafka/` directly into your project — it's small and dependency-free on the Mojo side.

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
    ))
    c.subscribe(["events"])
    for _ in range(100):
        var msg = c.poll(1000)
        if msg:
            print(msg.topic, msg.key, msg.value)
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
| `Producer` / `ProducerConfig` | Produce messages, async with `flush()` / `poll()` |
| `Consumer` / `ConsumerConfig` | Subscribe to topics, poll for messages, commit offsets |
| `AdminClient` | Create / delete / list topics |
| `Message` | `topic`, `partition`, `offset`, `key`, `value`, `timestamp_ms`, `headers` |
| `KafkaError` | Raised with `librdkafka` error code + human message |

Anything more exotic (transactions, schema registry, exactly-once semantics) — file an issue. We'd rather get the 80% smooth than the 100% half-baked.

## Project status

**Alpha — API may shift.** Initial scaffold targets `Mojo ≥ 24.6`. The FFI calls bind real `librdkafka` symbols, but you should expect rough edges around:

- Header passing on the consumer side
- Error code → exception mapping
- Lifetime of opaque handles across `^owned` transfers

If you hit one, please open an issue with a repro — that's the fastest way to harden this.

## Contributing

PRs welcome. The interesting layers to know about:

- `src/kafka/_ffi.mojo` — raw `librdkafka` symbol declarations
- `src/kafka/config.mojo` — typed config builder over `rd_kafka_conf_t`
- `src/kafka/producer.mojo` / `consumer.mojo` / `admin.mojo` — public API

Run the smoke tests against a local Kafka:

```bash
docker run -d --name=kafka -p 9092:9092 apache/kafka:3.7.0
mojo test tests/
```

## License

Apache 2.0. `librdkafka` itself is BSD-2-Clause and is dynamically linked, not bundled.
