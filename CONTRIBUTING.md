# Contributing

Thanks for considering a contribution. `mojo-kafka` is small and the bar for getting changes in is "does it move the alpha closer to a stable v0.1".

## Areas where help is especially welcome

- **Header support on the consumer side.** `_read_message` in `consumer.mojo` skips headers — we need the C struct walk and a Mojo-side `Dict[String, String]` exposed on `Message`.
- **Topic name on messages.** Today `Message.topic` is empty; reading it requires `rd_kafka_topic_name(rkt)` and a small lifetime story.
- **Error mapping.** `KafkaError.code` is the raw int. A `enum KafkaErrorKind` over the common cases would be nicer to pattern-match against.
- **Transactional producer.** `init_transactions / begin / commit / abort` aren't wrapped yet.
- **Schema registry / Avro / Protobuf.** Out of scope for v0.1 but would make a great second package.

## Workflow

1. Fork, branch off `main`.
2. Run `magic run test` locally — keep smoke tests green.
3. If you change the public API, update `README.md` and `examples/`.
4. Open a PR. Small focused PRs > big ones.

## Style

- Prefer Mojo stdlib types over custom ones.
- Keep `_ffi.mojo` the only file that touches `external_call`.
- One public symbol per concept (`Producer`, not `KafkaProducer` — the module already says `kafka`).
