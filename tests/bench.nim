import std/hashes
import std/times
import std/strutils
import std/streams
import std/lists
import std/intsets
import std/tables
import std/os
import std/random
import std/json
import std/uri

import criterion

import frosty

const
  fn = "goats"
let
  mode = if paramCount() < 1: "write" else: paramStr(1)
  count = if paramCount() < 2: 1 else: parseInt paramStr(2)
echo "benching against " & $count & " units in " & fn

let
  tJs = %* {
    "goats": ["pigs", "horses"],
    "sheep": 11,
    "ducks": 12.0,
    "dogs": "woof",
    "cats": false,
    "frogs": { "toads": true, "rats": "yep" },
  }

template writeSomething*(ss: Stream; w: typed): untyped =
  ss.setPosition 0
  if count == 1:
    freeze(w, ss)
  else:
    for i in 1 .. count:
      freeze(w, ss)

template readSomething*(ss: Stream; w: typed): untyped =
  var
    r: typeof(w)
  ss.setPosition 0
  if count == 1:
    thaw(ss, r)
  else:
    for i in 1 .. count:
      thaw(ss, r)
  r

const
  tSeq = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  tString = "https://irclogs.nim-lang.org/01-06-2020.html#20:54:23"
  tObj = parseUri(tString)
var
  tIntset = initIntSet()
for i in 0 .. 10:
  tIntset.incl i

var cfg = newDefaultConfig()
cfg.budget = 0.5

benchmark cfg:
  var
    ss = newStringStream()

  proc write_seq() {.measure.} =
    ss.writeSomething tSeq

  proc read_seq() {.measure.} =
    discard ss.readSomething tSeq

  proc write_string() {.measure.} =
    ss.writeSomething tString

  proc read_string() {.measure.} =
    discard ss.readSomething tString

  proc write_obj() {.measure.} =
    ss.writeSomething tObj

  proc read_obj() {.measure.} =
    discard ss.readSomething tObj

  proc write_intset() {.measure.} =
    ss.writeSomething tIntset

  proc read_intset() {.measure.} =
    let r = ss.readSomething tIntset

  proc write_json() {.measure.} =
    ss.writeSomething tJs

  proc read_json() {.measure.} =
    let r = ss.readSomething tJs
