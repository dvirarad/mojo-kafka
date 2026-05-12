"""Admin client — create / delete / list topics.

Built on the same conf+rk machinery as Producer; uses librdkafka's
NewTopic_t and rd_kafka_CreateTopics under the hood.
"""

from sys.ffi import external_call, OpaquePointer
from memory import UnsafePointer
from collections import List

from ._ffi import (
    RD_KAFKA_PRODUCER,
    err,
    rd_kafka_conf_new,
    rd_kafka_conf_set,
    rd_kafka_destroy,
    rd_kafka_new,
    rd_kafka_poll,
)


struct AdminClient:
    var _rk: OpaquePointer

    fn __init__(out self, bootstrap_servers: String) raises:
        var conf = rd_kafka_conf_new()
        rd_kafka_conf_set(conf, "bootstrap.servers", bootstrap_servers)
        self._rk = rd_kafka_new(RD_KAFKA_PRODUCER, conf)

    fn __del__(owned self):
        if self._rk:
            rd_kafka_destroy(self._rk)

    fn create_topic(
        self,
        name: String,
        num_partitions: Int32 = 1,
        replication_factor: Int32 = 1,
        timeout_ms: Int32 = 10000,
    ) raises:
        var errbuf = UnsafePointer[Int8].alloc(512)
        var new_topic = external_call[
            "rd_kafka_NewTopic_new",
            OpaquePointer,
            UnsafePointer[Int8],
            Int32,
            Int32,
            UnsafePointer[Int8],
            Int,
        ](name.unsafe_cstr_ptr(), num_partitions, replication_factor, errbuf, 512)
        if not new_topic:
            var msg = String(errbuf)
            errbuf.free()
            raise Error("rd_kafka_NewTopic_new: " + msg)
        errbuf.free()

        # rd_kafka_CreateTopics(rk, &new_topic, 1, options=NULL, queue=NULL)
        var arr = UnsafePointer[OpaquePointer].alloc(1)
        arr[0] = new_topic
        external_call[
            "rd_kafka_CreateTopics",
            NoneType,
            OpaquePointer,
            UnsafePointer[OpaquePointer],
            Int,
            OpaquePointer,
            OpaquePointer,
        ](self._rk, arr, 1, OpaquePointer(), OpaquePointer())

        _ = rd_kafka_poll(self._rk, timeout_ms)

        external_call["rd_kafka_NewTopic_destroy", NoneType, OpaquePointer](new_topic)
        arr.free()

    fn list_topics(self, timeout_ms: Int32 = 5000) raises -> List[String]:
        """Return topic names visible to this client."""
        var meta_out = UnsafePointer[OpaquePointer].alloc(1)
        var rc = external_call[
            "rd_kafka_metadata",
            Int32,
            OpaquePointer,
            Int32,
            OpaquePointer,
            UnsafePointer[OpaquePointer],
            Int32,
        ](self._rk, Int32(1), OpaquePointer(), meta_out, timeout_ms)
        if rc != 0:
            meta_out.free()
            raise Error(String(err(rc)))

        var meta = meta_out[0]
        # struct rd_kafka_metadata { int broker_cnt; void*; int topic_cnt; rd_kafka_metadata_topic_t *topics; ... }
        var base = meta.bitcast[UInt8]()
        var topic_cnt = base.offset(16).bitcast[Int32]().load()
        var topics_ptr = base.offset(24).bitcast[UnsafePointer[UInt8]]().load()

        var out = List[String]()
        # sizeof(rd_kafka_metadata_topic_t) layout begins with `char *topic; int partition_cnt; ...`
        # On 64-bit, char* is 8 bytes, then 4 bytes partition_cnt, padding... the next struct
        # alignment in librdkafka is 24 bytes per topic entry on 64-bit systems.
        var stride = 24
        for i in range(Int(topic_cnt)):
            var name_ptr = topics_ptr.offset(i * stride).bitcast[UnsafePointer[Int8]]().load()
            if name_ptr:
                out.append(String(name_ptr))

        external_call["rd_kafka_metadata_destroy", NoneType, OpaquePointer](meta)
        meta_out.free()
        return out
