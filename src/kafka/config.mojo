"""Typed configuration objects.

These are thin builders that emit a `rd_kafka_conf_t*` on demand. The
type-level field names match librdkafka's documented keys exactly, with
underscores instead of dots (`bootstrap_servers` -> `bootstrap.servers`)
to stay Mojo-idiomatic.
"""

from sys.ffi import OpaquePointer
from collections import Dict
from ._ffi import rd_kafka_conf_new, rd_kafka_conf_set


fn _key_to_librdkafka(name: String) -> String:
    """Map `bootstrap_servers` -> `bootstrap.servers`. librdkafka keys use dots.
    """
    return name.replace("_", ".")


@value
struct ProducerConfig:
    var bootstrap_servers: String
    var client_id: String
    var compression_type: String
    var linger_ms: Int
    var acks: String
    var extra: Dict[String, String]

    fn __init__(
        out self,
        bootstrap_servers: String,
        client_id: String = "mojo-kafka",
        compression_type: String = "none",
        linger_ms: Int = 0,
        acks: String = "all",
    ):
        self.bootstrap_servers = bootstrap_servers
        self.client_id = client_id
        self.compression_type = compression_type
        self.linger_ms = linger_ms
        self.acks = acks
        self.extra = Dict[String, String]()

    fn set(mut self, key: String, value: String):
        """Escape hatch for any librdkafka key we don't expose as a field."""
        self.extra[key] = value

    fn _build(self) raises -> OpaquePointer:
        var conf = rd_kafka_conf_new()
        rd_kafka_conf_set(conf, "bootstrap.servers", self.bootstrap_servers)
        rd_kafka_conf_set(conf, "client.id", self.client_id)
        rd_kafka_conf_set(conf, "compression.type", self.compression_type)
        rd_kafka_conf_set(conf, "linger.ms", String(self.linger_ms))
        rd_kafka_conf_set(conf, "acks", self.acks)
        for item in self.extra.items():
            rd_kafka_conf_set(
                conf, _key_to_librdkafka(item[].key), item[].value
            )
        return conf


@value
struct ConsumerConfig:
    var bootstrap_servers: String
    var group_id: String
    var client_id: String
    var auto_offset_reset: String
    var enable_auto_commit: Bool
    var extra: Dict[String, String]

    fn __init__(
        out self,
        bootstrap_servers: String,
        group_id: String,
        client_id: String = "mojo-kafka",
        auto_offset_reset: String = "latest",
        enable_auto_commit: Bool = True,
    ):
        self.bootstrap_servers = bootstrap_servers
        self.group_id = group_id
        self.client_id = client_id
        self.auto_offset_reset = auto_offset_reset
        self.enable_auto_commit = enable_auto_commit
        self.extra = Dict[String, String]()

    fn set(mut self, key: String, value: String):
        self.extra[key] = value

    fn _build(self) raises -> OpaquePointer:
        var conf = rd_kafka_conf_new()
        rd_kafka_conf_set(conf, "bootstrap.servers", self.bootstrap_servers)
        rd_kafka_conf_set(conf, "group.id", self.group_id)
        rd_kafka_conf_set(conf, "client.id", self.client_id)
        rd_kafka_conf_set(conf, "auto.offset.reset", self.auto_offset_reset)
        rd_kafka_conf_set(
            conf,
            "enable.auto.commit",
            "true" if self.enable_auto_commit else "false",
        )
        for item in self.extra.items():
            rd_kafka_conf_set(
                conf, _key_to_librdkafka(item[].key), item[].value
            )
        return conf
