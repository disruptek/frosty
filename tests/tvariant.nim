import balls
import frosty

type
  G = enum
    Even
    Odd
  VType = object
    ignore: bool
    case kind: G
    of Even:
      even: int
    of Odd:
      odd: bool

suite "object variants":
  var s: string
  block:
    ## write a case object
    let v = VType(ignore: true, kind: Even, even: 6)
    s = freeze(v)
  block:
    ## read a case object
    var v: VType
    thaw[VType](s, v)
    assert v.ignore == true
    assert v.kind == Even
    assert v.even == 6
