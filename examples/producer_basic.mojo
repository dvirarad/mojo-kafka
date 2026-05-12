"""Minimal producer example.

Run a local Kafka first:

    docker run -d --name=kafka -p 9092:9092 apache/kafka:3.7.0

Then:

    mojo run examples/producer_basic.mojo
"""

from kafka import Producer, ProducerConfig


fn main() raises:
    var cfg = ProducerConfig(
        bootstrap_servers="localhost:9092",
        client_id="mojo-kafka-example",
        linger_ms=5,
    )
    var p = Producer(cfg)

    for i in range(10):
        var key = "user-" + String(i)
        var value = '{"event":"login","seq":' + String(i) + "}"
        p.produce(topic="events", value=value, key=key)
        _ = p.poll(0)

    p.flush(5000)
    print("Produced 10 messages to 'events'.")
