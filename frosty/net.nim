import std/net

proc writeString[T](s: var Serializer[Socket]; o: T)
proc readString[T](s: var Serializer[Socket]; o: var T)
proc readPrimitive[T](s: var Serializer[Socket]; o: var T)
proc writePrimitive[T](s: var Serializer[Socket]; o: T)

# convenience to make certain calls more legible
template socket(s: Serializer): Socket = s.stream

proc writeString[T](s: var Serializer[Socket]; o: T) =
  var l = len(o)            # type inference
  # send the length of the string
  if send(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
    raise newException(FreezeError, "short write; socket closed?")
  # send the string itself; this can raise...
  send(s.socket, data = o)

proc readString[T](s: var Serializer[Socket]; o: var T) =
  var l = len(o)            # type inference
  # receive the string size
  if recv(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
    raise newException(ThawError, "short read; socket closed?")
  # for the following recv(), "data must be initialized"
  setLen(o, l)
  if l > 0:
    # receive the string
    if recv(s.socket, data = o, size = l) != l:
      raise newException(ThawError, "short read; socket closed?")

proc writePrimitive[T](s: var Serializer[Socket]; o: T) =
  if send(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
    raise newException(FreezeError, "short write; socket closed?")

proc readPrimitive[T](s: var Serializer[Socket]; o: var T) =
  if net.recv(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
    raise newException(ThawError, "short read; socket closed?")

proc freeze*[T](socket: Socket; o: T) =
  ## Send `o` via `socket`.
  var s: Serializer[Socket]
  initSerializer(s, socket)
  s.write o

proc thaw*[T](socket: Socket; o: var T) =
  ## Receive `o` from `socket`.
  var s: Serializer[Socket]
  initSerializer(s, socket)
  s.read o
