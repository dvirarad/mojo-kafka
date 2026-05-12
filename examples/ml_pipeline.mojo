"""Hero example: a streaming ML feature pipeline.

Consumes JSON events off Kafka, parses out a numeric feature vector, runs a
toy "inference" step over them, and prints the prediction. Replace the
`run_inference` body with a real MAX/Mojo model — the streaming layer
above it doesn't change.

This is the whole reason `mojo-kafka` exists: keep the data-path in Mojo
end-to-end so you don't pay a Python hop per message.
"""

from kafka import Consumer, ConsumerConfig


fn parse_feature(value: String) -> Float64:
    """Toy parser — pulls the first numeric token out of `value`."""
    var acc = String("")
    var seen_digit = False
    for ch in value:
        if ch[].isdigit() or ch[] == "." or (not seen_digit and ch[] == "-"):
            acc += ch[]
            seen_digit = True
        elif seen_digit:
            break
    if len(acc) == 0:
        return 0.0
    return Float64(atof(acc))


fn run_inference(feature: Float64) -> Float64:
    """Stand-in for a real model. Logistic-ish over a single input."""
    var x = feature
    var s = 1.0 / (1.0 + (-x).exp())
    return s


fn main() raises:
    var c = Consumer(
        ConsumerConfig(
            bootstrap_servers="localhost:9092",
            group_id="mojo-ml-pipeline",
            auto_offset_reset="earliest",
        )
    )
    c.subscribe(["features"])

    print("Listening on 'features' — Ctrl-C to stop.")
    while True:
        var maybe = c.poll(timeout_ms=1000)
        if not maybe:
            continue
        var m = maybe.value()
        var x = parse_feature(m.value)
        var y = run_inference(x)
        print("offset=", m.offset, " x=", x, " y_hat=", y)
