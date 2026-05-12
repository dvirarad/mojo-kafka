"""Raw librdkafka FFI declarations.

This is the only file that talks to C directly. Everything else in the
package goes through the symbols defined here so that bumping librdkafka
or switching loader strategies (`DLHandle` vs static link) stays local.
"""

from sys.ffi import external_call, DLHandle, OpaquePointer
from memory import UnsafePointer


alias RD_KAFKA_PRODUCER: Int32 = 0
alias RD_KAFKA_CONSUMER: Int32 = 1

alias RD_KAFKA_RESP_ERR_NO_ERROR: Int32 = 0
alias RD_KAFKA_RESP_ERR__TIMED_OUT: Int32 = -185
alias RD_KAFKA_RESP_ERR__PARTITION_EOF: Int32 = -191

# rd_kafka_vtype_t for rd_kafka_producev variadic args
alias RD_KAFKA_VTYPE_END: Int32 = 0
alias RD_KAFKA_VTYPE_TOPIC: Int32 = 1
alias RD_KAFKA_VTYPE_KEY: Int32 = 4
alias RD_KAFKA_VTYPE_VALUE: Int32 = 5


@value
struct KafkaError(Stringable):
    """Wraps a librdkafka rd_kafka_resp_err_t with its human description."""

    var code: Int32
    var message: String

    fn __str__(self) -> String:
        return "KafkaError(" + String(Int(self.code)) + "): " + self.message


fn rd_kafka_version() -> Int32:
    """librdkafka build version as a packed int (MM.mm.rr.xx)."""
    return external_call["rd_kafka_version", Int32]()


fn rd_kafka_version_str() -> String:
    var p = external_call["rd_kafka_version_str", UnsafePointer[Int8]]()
    return String(p)


fn librdkafka_version() -> String:
    """Public convenience — version string of the loaded librdkafka."""
    return rd_kafka_version_str()


fn rd_kafka_err2str(code: Int32) -> String:
    var p = external_call["rd_kafka_err2str", UnsafePointer[Int8], Int32](code)
    return String(p)


fn err(code: Int32) -> KafkaError:
    return KafkaError(code, rd_kafka_err2str(code))


# --- conf_t -----------------------------------------------------------------


fn rd_kafka_conf_new() -> OpaquePointer:
    return external_call["rd_kafka_conf_new", OpaquePointer]()


fn rd_kafka_conf_destroy(conf: OpaquePointer):
    external_call["rd_kafka_conf_destroy", NoneType, OpaquePointer](conf)


fn rd_kafka_conf_set(
    conf: OpaquePointer,
    name: String,
    value: String,
) raises:
    """Set a librdkafka config key. Raises if the key/value pair is rejected."""
    var errbuf = UnsafePointer[Int8].alloc(512)
    var rc = external_call[
        "rd_kafka_conf_set",
        Int32,
        OpaquePointer,
        UnsafePointer[Int8],
        UnsafePointer[Int8],
        UnsafePointer[Int8],
        Int,
    ](conf, name.unsafe_cstr_ptr(), value.unsafe_cstr_ptr(), errbuf, 512)
    if rc != 0:
        var msg = String(errbuf)
        errbuf.free()
        raise Error("rd_kafka_conf_set(" + name + "=" + value + "): " + msg)
    errbuf.free()


# --- rd_kafka_t -------------------------------------------------------------


fn rd_kafka_new(
    rk_type: Int32,
    conf: OpaquePointer,
) raises -> OpaquePointer:
    var errbuf = UnsafePointer[Int8].alloc(512)
    var rk = external_call[
        "rd_kafka_new",
        OpaquePointer,
        Int32,
        OpaquePointer,
        UnsafePointer[Int8],
        Int,
    ](rk_type, conf, errbuf, 512)
    if not rk:
        var msg = String(errbuf)
        errbuf.free()
        raise Error("rd_kafka_new: " + msg)
    errbuf.free()
    return rk


fn rd_kafka_destroy(rk: OpaquePointer):
    external_call["rd_kafka_destroy", NoneType, OpaquePointer](rk)


fn rd_kafka_poll(rk: OpaquePointer, timeout_ms: Int32) -> Int32:
    return external_call["rd_kafka_poll", Int32, OpaquePointer, Int32](
        rk, timeout_ms
    )


fn rd_kafka_flush(rk: OpaquePointer, timeout_ms: Int32) -> Int32:
    return external_call["rd_kafka_flush", Int32, OpaquePointer, Int32](
        rk, timeout_ms
    )


# --- consumer ---------------------------------------------------------------


fn rd_kafka_poll_set_consumer(rk: OpaquePointer) -> Int32:
    return external_call["rd_kafka_poll_set_consumer", Int32, OpaquePointer](rk)


fn rd_kafka_subscribe(rk: OpaquePointer, topics: OpaquePointer) -> Int32:
    return external_call[
        "rd_kafka_subscribe", Int32, OpaquePointer, OpaquePointer
    ](rk, topics)


fn rd_kafka_consumer_poll(
    rk: OpaquePointer, timeout_ms: Int32
) -> OpaquePointer:
    return external_call[
        "rd_kafka_consumer_poll",
        OpaquePointer,
        OpaquePointer,
        Int32,
    ](rk, timeout_ms)


fn rd_kafka_message_destroy(msg: OpaquePointer):
    external_call["rd_kafka_message_destroy", NoneType, OpaquePointer](msg)


fn rd_kafka_consumer_close(rk: OpaquePointer) -> Int32:
    return external_call["rd_kafka_consumer_close", Int32, OpaquePointer](rk)


# --- topic partition list ---------------------------------------------------


fn rd_kafka_topic_partition_list_new(size: Int32) -> OpaquePointer:
    return external_call[
        "rd_kafka_topic_partition_list_new", OpaquePointer, Int32
    ](size)


fn rd_kafka_topic_partition_list_destroy(list: OpaquePointer):
    external_call[
        "rd_kafka_topic_partition_list_destroy", NoneType, OpaquePointer
    ](list)


fn rd_kafka_topic_partition_list_add(
    list: OpaquePointer, topic: String, partition: Int32
) -> OpaquePointer:
    return external_call[
        "rd_kafka_topic_partition_list_add",
        OpaquePointer,
        OpaquePointer,
        UnsafePointer[Int8],
        Int32,
    ](list, topic.unsafe_cstr_ptr(), partition)
