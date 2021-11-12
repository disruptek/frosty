import std/streams

import frosty
export freeze, FreezeError, thaw, ThawError, origin

type
  Streamy = Stream or StringStream

template rewriteIOErrorAs(exception: typed; logic: untyped): untyped =
  try:
    logic
  except IOError as e:
    raise frostyError(exception, e)

proc serialize*(output: var Streamy; input: string; len: int) =
  rewriteIOErrorAs FreezeError:
    write(output, input)

proc deserialize*(input: var Streamy; output: var string; len: int) =
  rewriteIOErrorAs ThawError:
    readStr(input, len, output)

proc serialize*[T](output: var Streamy; input: T) =
  rewriteIOErrorAs FreezeError:
    write(output, input)

proc deserialize*[T](input: var Streamy; output: var T) =
  rewriteIOErrorAs ThawError:
    read(input, output)

proc freeze*[T](result: string; source: T)
  {.error: "cannot freeze into an immutable string".}

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
