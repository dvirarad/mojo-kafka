"""Minimal consumer example.

Pair this with `examples/producer_basic.mojo` to see messages flow end-to-end.
"""

from kafka import Consumer, ConsumerConfig


fn main() raises:
    var cfg = ConsumerConfig(
        bootstrap_servers="localhost:9092",
        group_id="mojo-kafka-example",
        auto_offset_reset="earliest",
    )
    var c = Consumer(cfg)
    c.subscribe(["events"])

    var seen = 0
    while seen < 10:
        var maybe = c.poll(timeout_ms=1000)
        if maybe:
            var m = maybe.value()
            print("partition=", m.partition, " offset=", m.offset, " key=", m.key, " value=", m.value)
            seen += 1

    c.close()
