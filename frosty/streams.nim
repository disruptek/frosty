import std/streams

import frosty
export frosty

type
  Streamy = Stream or StringStream

proc serialize*(output: var Streamy; input: string; len: int) =
  write(output, input)

proc deserialize*(input: var Streamy; output: var string; len: int) =
  readStr(input, len, output)

proc serialize*[T](output: var Streamy; input: T) =
  write(output, input)

proc deserialize*[T](input: var Streamy; output: var T) =
  read(input, output)

when false:
  proc freeze*[T](stream: Stream; source: T) =
    ## Write `source` into `stream`.
    var s = Serializer(serial: stream)
    deserialize(s, source)

when true:
  proc freeze*[T](result: var string; source: T) =
    ## Write `source` into `result`.
    runnableExamples:
      import uri
      # start with some data
      var q = parseUri"https://github.com/disruptek/frosty"
      # prepare a string
      var s: string
      # write the data into the string
      freeze(s, q)
      # prepare a new url object
      var url: Uri
      # populate the url using the string as input
      thaw(s, url)
      # confirm that two objects match
      assert url == q

    var stream = newStringStream result
    try:
      stream.freeze source
      stream.setPosition 0
      result = readAll stream
    finally:
      close stream

  proc freeze*[T](source: T): string =
    ## Turn a `T` into a string.
    runnableExamples:
      import uri
      # start with some data
      var q = parseUri"https://github.com/disruptek/frosty"
      # freeze `q` into `s`
      var s = freeze(q)
      # thaw `s` into `u`
      var u = thaw[Uri](s)
      # confirm that two objects match
      assert u == q

    result.freeze source

when false:
  proc thaw*[T](stream: Stream; result: var T) =
    ## Read `result` from `stream`.
    var s: Serializer(serial: stream)
    deserialize(s, result)

when true:
  proc thaw*[T](source: string; result: var T) =
    ## Read `result` from `source`.
    runnableExamples:
      # start with some data
      var q = @[1, 1, 2, 3, 5]
      # prepare a string
      var s: string
      # write the data into the string
      s.freeze q
      # check that it matches our expectation
      assert len(s) == sizeof(int) + 5*sizeof(int)
      # prepare a new seq to hold some data
      var l: seq[int]
      # populate the seq using the string as input
      s.thaw l
      # confirm that the two sequences of data match
      assert l == q

    var stream = newStringStream source
    try:
      thaw(stream, result)
    finally:
      close stream

  proc thaw*[T](source: string): T =
    ## Turn a string into a `T`.
    var stream = newStringStream source
    try:
      thaw(stream, result)
    finally:
      close stream
