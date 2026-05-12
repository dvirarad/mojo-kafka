"""High-level consumer."""

from sys.ffi import OpaquePointer
from memory import UnsafePointer
from collections import List

from ._ffi import (
    RD_KAFKA_CONSUMER,
    RD_KAFKA_RESP_ERR_NO_ERROR,
    RD_KAFKA_RESP_ERR__PARTITION_EOF,
    err,
    rd_kafka_consumer_close,
    rd_kafka_consumer_poll,
    rd_kafka_destroy,
    rd_kafka_message_destroy,
    rd_kafka_new,
    rd_kafka_poll_set_consumer,
    rd_kafka_subscribe,
    rd_kafka_topic_partition_list_add,
    rd_kafka_topic_partition_list_destroy,
    rd_kafka_topic_partition_list_new,
)
from .config import ConsumerConfig


# Layout of rd_kafka_message_t (librdkafka public ABI). We mirror only the
# fields we need so we can read them by offset from the returned pointer.
# struct rd_kafka_message_s {
#   rd_kafka_resp_err_t err;        /* 4 bytes (Int32) */
#   void *rkt;                       /* 8 bytes */
#   int32_t partition;               /* 4 bytes */
#   void *payload;                   /* 8 bytes */
#   size_t len;                      /* 8 bytes */
#   void *key;                       /* 8 bytes */
#   size_t key_len;                  /* 8 bytes */
#   int64_t offset;                  /* 8 bytes */
#   void *_private;                  /* 8 bytes */
# };
# Note: padded to 8-byte alignment after `err`/`partition`.


@value
struct Message:
    var topic: String
    var partition: Int32
    var offset: Int64
    var key: String
    var value: String


fn _read_message(raw: OpaquePointer) raises -> Message:
    """Decode a `rd_kafka_message_t*` into a `Message` by offsets."""
    var base = raw.bitcast[UInt8]()
    var err_code = base.offset(0).bitcast[Int32]().load()
    if err_code != RD_KAFKA_RESP_ERR_NO_ERROR and err_code != RD_KAFKA_RESP_ERR__PARTITION_EOF:
        raise Error(String(err(err_code)))

    var partition = base.offset(16).bitcast[Int32]().load()
    var payload_ptr = base.offset(24).bitcast[UnsafePointer[Int8]]().load()
    var payload_len = base.offset(32).bitcast[Int]().load()
    var key_ptr = base.offset(40).bitcast[UnsafePointer[Int8]]().load()
    var key_len = base.offset(48).bitcast[Int]().load()
    var offset = base.offset(56).bitcast[Int64]().load()

    var value_str = String("")
    if payload_ptr and payload_len > 0:
        value_str = String(payload_ptr, payload_len)

    var key_str = String("")
    if key_ptr and key_len > 0:
        key_str = String(key_ptr, key_len)

    # Topic name comes from rkt via rd_kafka_topic_name(rkt). For the alpha
    # we expose partition+offset and let the caller track topic out-of-band.
    # Full topic lookup is a TODO once we add a typed rkt handle.
    return Message("", partition, offset, key_str, value_str)


struct Consumer:
    """A consumer group member over librdkafka."""

    var _rk: OpaquePointer
    var _closed: Bool

    fn __init__(out self, owned cfg: ConsumerConfig) raises:
        var conf = cfg._build()
        self._rk = rd_kafka_new(RD_KAFKA_CONSUMER, conf)
        _ = rd_kafka_poll_set_consumer(self._rk)
        self._closed = False

    fn __del__(owned self):
        if not self._closed and self._rk:
            _ = rd_kafka_consumer_close(self._rk)
        if self._rk:
            rd_kafka_destroy(self._rk)

    fn subscribe(self, topics: List[String]) raises:
        var list = rd_kafka_topic_partition_list_new(Int32(len(topics)))
        for t in topics:
            _ = rd_kafka_topic_partition_list_add(list, t[], -1)
        var rc = rd_kafka_subscribe(self._rk, list)
        rd_kafka_topic_partition_list_destroy(list)
        if rc != 0:
            raise Error(String(err(rc)))

    fn poll(self, timeout_ms: Int32 = 1000) raises -> Optional[Message]:
        """Fetch the next message. Returns None on timeout."""
        var raw = rd_kafka_consumer_poll(self._rk, timeout_ms)
        if not raw:
            return None
        try:
            var m = _read_message(raw)
            rd_kafka_message_destroy(raw)
            return m
        except e:
            rd_kafka_message_destroy(raw)
            raise e

    fn close(mut self) raises:
        if not self._closed:
            var rc = rd_kafka_consumer_close(self._rk)
            self._closed = True
            if rc != 0:
                raise Error(String(err(rc)))
