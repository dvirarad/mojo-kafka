"""High-level producer."""

from sys.ffi import external_call, OpaquePointer
from memory import UnsafePointer

from ._ffi import (
    RD_KAFKA_PRODUCER,
    RD_KAFKA_VTYPE_END,
    RD_KAFKA_VTYPE_TOPIC,
    RD_KAFKA_VTYPE_KEY,
    RD_KAFKA_VTYPE_VALUE,
    err,
    rd_kafka_destroy,
    rd_kafka_flush,
    rd_kafka_new,
    rd_kafka_poll,
)
from .config import ProducerConfig


struct Producer:
    """A producer over librdkafka.

    Construct from a `ProducerConfig` and call `produce(...)` repeatedly.
    Call `flush()` before drop to wait for in-flight messages to ack.
    """

    var _rk: OpaquePointer

    fn __init__(out self, owned cfg: ProducerConfig) raises:
        var conf = cfg._build()
        # rd_kafka_new takes ownership of conf on success.
        self._rk = rd_kafka_new(RD_KAFKA_PRODUCER, conf)

    fn __del__(owned self):
        if self._rk:
            _ = rd_kafka_flush(self._rk, 5000)
            rd_kafka_destroy(self._rk)

    fn produce(
        self,
        topic: String,
        value: String,
        key: String = "",
    ) raises:
        """Enqueue a message. Returns immediately; ack arrives on next `poll()`."""
        var rc = external_call[
            "rd_kafka_producev",
            Int32,
            OpaquePointer,
            # vtype, topic
            Int32, UnsafePointer[Int8],
            # vtype, key, klen
            Int32, UnsafePointer[Int8], Int,
            # vtype, value, vlen
            Int32, UnsafePointer[Int8], Int,
            # END
            Int32,
        ](
            self._rk,
            RD_KAFKA_VTYPE_TOPIC, topic.unsafe_cstr_ptr(),
            RD_KAFKA_VTYPE_KEY, key.unsafe_cstr_ptr(), len(key),
            RD_KAFKA_VTYPE_VALUE, value.unsafe_cstr_ptr(), len(value),
            RD_KAFKA_VTYPE_END,
        )
        if rc != 0:
            raise Error(String(err(rc)))

    fn poll(self, timeout_ms: Int32 = 0) -> Int32:
        """Drive delivery callbacks. Returns number of events processed."""
        return rd_kafka_poll(self._rk, timeout_ms)

    fn flush(self, timeout_ms: Int32 = 5000) raises:
        """Block until all enqueued messages are sent or `timeout_ms` elapses."""
        var rc = rd_kafka_flush(self._rk, timeout_ms)
        if rc != 0:
            raise Error(String(err(rc)))
