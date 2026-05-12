# Architecture

This is the longer write-up on how `mojo-kafka` is layered. Read [`README.md`](../README.md) first for the usage story; this document is for contributors and people considering the FFI design.

## Layers

```
┌────────────────────────────────────────────────────────┐
│  user code (Mojo / MAX)                                │
│     from kafka import Producer, Consumer, AdminClient  │
├────────────────────────────────────────────────────────┤  ← public Mojo surface
│  Pythonic Mojo API                                     │
│     src/kafka/__init__.mojo                            │
│     src/kafka/{producer,consumer,admin,config}.mojo    │
│     src/kafka/error.mojo                               │
├────────────────────────────────────────────────────────┤  ← `external_call`
│  raw FFI surface                                       │
│     src/kafka/_ffi.mojo                                │
├────────────────────────────────────────────────────────┤  ← C ABI
│  librdkafka.so / .dylib   (BSD-2-Clause, dynamic)      │
└────────────────────────────────────────────────────────┘
```

Each arrow is a contract. The Mojo layer hides everything underneath — users see typed `struct`s and Mojo exceptions, not `OpaquePointer`s or `rd_kafka_resp_err_t` ints.

## Why `librdkafka`

It's the C foundation under almost every non-JVM Kafka client (Confluent Python / Go / .NET, node-rdkafka, Rust `rdkafka`, etc.). That means:

- The wire protocol, broker compatibility, transactions, and exactly-once semantics are battle-tested.
- Behavior under network failure, rebalance, and broker upgrade matches what production Kafka users expect.
- We inherit the documentation, the bug fixes, and the `librdkafka` mailing-list culture.

Writing the Kafka wire protocol from scratch in Mojo would be more "native" but would either take years or be subtly broken on real clusters. We chose battle-tested over native.

## Why a Pythonic Mojo API

Mojo's superpower is being Python-like. Two consequences:

1. The audience most likely to pick this up is Python data / ML engineers — `confluent-kafka-python` is the API they know.
2. Mojo has direct syntactic support for Python-style `class`-like usage via `struct`. Mirroring the Python API costs little and lowers the learning curve to ~zero.

We diverge from `confluent-kafka-python` only where:
- Mojo's lack of `**kwargs` would make a Python-style call awkward (we use explicit fields on `ProducerConfig` / `ConsumerConfig`).
- Mojo's resource management (`__del__`) lets us drop the explicit `del consumer` dance.

## FFI design: `_ffi.mojo`

This file declares every `librdkafka` symbol we call. Each declaration looks like:

```mojo
alias rd_kafka_new_t = fn (
    type: Int32,
    conf: OpaquePointer,
    errstr: UnsafePointer[UInt8],
    errstr_size: Int,
) -> OpaquePointer

@always_inline
fn rd_kafka_new(
    type: Int32,
    conf: OpaquePointer,
    errstr: UnsafePointer[UInt8],
    errstr_size: Int,
) -> OpaquePointer:
    return external_call["rd_kafka_new", OpaquePointer](type, conf, errstr, errstr_size)
```

Two rules we follow rigidly:

1. **One `external_call` per symbol.** No higher-level conveniences here. The point of this layer is auditability — anyone tracing `librdkafka` documentation should be able to find the corresponding declaration verbatim.
2. **Mojo types only.** No `__init__`, no methods. Lifetime is the caller's problem at this layer. The `Producer` / `Consumer` structs above own the lifetimes.

## Lifetime story

Every `librdkafka` resource has a paired `_new` / `_destroy` (or `_free`). The Mojo wrappers tie that to Mojo's RAII:

- `Producer.__init__` calls `rd_kafka_new(RD_KAFKA_PRODUCER, …)` and stores the resulting `rd_kafka_t*` as `OpaquePointer`.
- `Producer.__del__` calls `rd_kafka_flush(timeout=10s)` then `rd_kafka_destroy`.
- Same pattern for `Consumer` (with an explicit `close()` for graceful rebalance), and for `AdminClient`.

`ProducerConfig._build()` returns the `rd_kafka_conf_t*` and **transfers ownership** to `rd_kafka_new` — which is what `librdkafka` expects. If `rd_kafka_new` fails, we still need to `rd_kafka_conf_destroy`; the wrapper does that in the error path.

## Error mapping

`librdkafka` returns `rd_kafka_resp_err_t` (a 32-bit enum). We:

1. Translate it to a human string via `rd_kafka_err2str`.
2. Wrap both into our `KafkaError(code: Int32, message: String)`.
3. `raise` it from any wrapper that detected a non-`NO_ERROR` code.

The roadmap is to expose a typed `KafkaErrorKind` enum so users can `match` on specific errors instead of comparing magic numbers — see [#3](https://github.com/dvirarad/mojo-kafka/issues/3).

## Reading `rd_kafka_message_t`

`rd_kafka_message_t` is a C struct with a public field layout. We decode it at known byte offsets:

| Field    | Offset | Type             |
|----------|-------:|------------------|
| `err`    |      0 | `rd_kafka_resp_err_t` (Int32) |
| `rkt`    |      8 | `rd_kafka_topic_t*` (opaque) |
| `partition` | 16 | Int32            |
| `payload` | 24    | `void*`          |
| `len`    |     32 | size_t (Int)     |
| `key`    |     40 | `void*`          |
| `key_len` |    48 | size_t (Int)     |
| `offset` |     56 | int64            |

This is fragile — if `librdkafka` ever re-orders the public struct (it won't; it's ABI-stable), every consumer breaks. We pin `librdkafka >= 2.3.0` to lock the layout we tested against.

## What we do *not* do

- We don't ship `librdkafka` itself. We dynamic-link against whatever the user provides (system package, conda-forge, or vendored).
- We don't implement transactions / exactly-once / Schema Registry yet — those are explicit v0.2 / v0.3 work in [Roadmap](../README.md#roadmap).
- We don't expose `librdkafka`'s callback-driven API. The Mojo idiom is a polling loop; we lean into that.

## Testing strategy

- **Smoke tests** (`tests/test_smoke.mojo`) — instantiate every type with sane configs and tear them down. No broker required; catches FFI breakage and obvious memory issues.
- **Integration tests** — run smoke + a few real produce/consume round-trips against a real `apache/kafka:3.7.0` broker spun up as a CI service container.
- **Lint** — `mojo format --check` over `src/`, `examples/`, `tests/`.

All three gate every PR. See `.github/workflows/ci.yml`.
