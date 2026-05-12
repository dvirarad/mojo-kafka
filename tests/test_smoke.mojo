"""Smoke tests — no broker required."""

from kafka import librdkafka_version, ProducerConfig, ConsumerConfig


def test_librdkafka_loadable():
    """If `librdkafka.so` isn't on the loader path, this errors at link time."""
    var v = librdkafka_version()
    assert_true(len(v) > 0)


def test_producer_config_defaults():
    var cfg = ProducerConfig(bootstrap_servers="localhost:9092")
    assert_equal(cfg.client_id, "mojo-kafka")
    assert_equal(cfg.acks, "all")


def test_consumer_config_defaults():
    var cfg = ConsumerConfig(bootstrap_servers="localhost:9092", group_id="g")
    assert_equal(cfg.group_id, "g")
    assert_equal(cfg.auto_offset_reset, "latest")
    assert_true(cfg.enable_auto_commit)


def test_extra_keys_underscore_to_dot():
    var cfg = ProducerConfig(bootstrap_servers="localhost:9092")
    cfg.set("message_max_bytes", "1000000")
    assert_equal(cfg.extra["message_max_bytes"], "1000000")


fn assert_true(b: Bool) raises:
    if not b:
        raise Error("assertion failed")


fn assert_equal[T: EqualityComparable & Stringable](a: T, b: T) raises:
    if a != b:
        raise Error("expected " + String(b) + " got " + String(a))
