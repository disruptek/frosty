import std/streams

template asString(s: typed): untyped =
  when s is string:
    s
  else:
    string(s)

proc writeString(s: var Serializer[Stream]; o: string)
proc readString(s: var Serializer[Stream]; o: var string)
proc readPrimitive[T](s: var Serializer[Stream]; o: var T)
proc writePrimitive[T](s: var Serializer[Stream]; o: T)

proc writeString(s: var Serializer[Stream]; o: string) =
  ## write a string or string-like thing
  write(s, o.len)                # put the str len
  write(s.stream, asString o)    # put the str data

proc readString(s: var Serializer[Stream]; o: var string) =
  ## read a string or string-like thing
  var l = len(asString o)        # type inference
  read(s, l)                     # read the string length
  setLen(asString o, l)          # set the new length
  if l > 0:
    if readData(s.stream, o.cstring, l) != l:
      raise ThawError.newException "short read!"

proc writePrimitive[T](s: var Serializer[Stream]; o: T) =
  write(s.stream, o)

proc readPrimitive[T](s: var Serializer[Stream]; o: var T) =
  read(s.stream, o)

proc freeze*[T](stream: Stream; source: T) =
  ## Write `source` into `stream`.
  var s: Serializer[Stream]
  initSerializer(s, stream)
  write(s, source)

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

  var ss = newStringStream result
  try:
    ss.freeze source
    ss.setPosition 0
    result = readAll ss
  finally:
    close ss

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

proc thaw*[T](stream: Stream; result: var T) =
  ## Read `result` from `stream`.
  var s: Serializer[Stream]
  initSerializer(s, stream)
  read(s, result)

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

  var ss = newStringStream source
  try:
    ss.thaw result
  finally:
    close ss

proc thaw*[T](source: string): T =
  ## Turn a string into a `T`.
  source.thaw result
