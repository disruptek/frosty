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

var
  tJsA {.compileTime.} = newJArray()
  tJsO {.compileTime.} = newJObject()
  tJs {.compileTime.} = newJObject()

tJsA.add newJString"pigs"
tJsA.add newJString"horses"

tJsO.add "toads", newJBool(true)
tJsO.add "rats", newJString"yep"

for k, v in {
  "goats": tJsA,
  "sheep": newJInt(11),
  "ducks": newJFloat(12.0),
  "dogs": newJString("woof"),
  "cats": newJBool(false),
  "frogs": tJsO,
}.items:
  tJs[k] = v

const
  jsSize = len($tJs)

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
cfg.brief = true

benchmark cfg:
  var
    ss = newStringStream()

  proc write_seq() {.measure.} =
    ss.writeSomething tSeq

  proc read_seq() {.measure.} =
    discard ss.readSomething tSeq

benchmark cfg:
  var
    ss = newStringStream()

  proc write_string() {.measure.} =
    ss.writeSomething tString

  proc read_string() {.measure.} =
    discard ss.readSomething tString

benchmark cfg:
  var
    ss = newStringStream()

  proc write_obj() {.measure.} =
    ss.writeSomething tObj

  proc read_obj() {.measure.} =
    discard ss.readSomething tObj

benchmark cfg:
  var
    ss = newStringStream()

  proc write_intset() {.measure.} =
    ss.writeSomething tIntset

  proc read_intset() {.measure.} =
    let r = ss.readSomething tIntset

benchmark cfg:
  var
    ss = newStringStream()

  proc write_json_stdlib() {.measure.} =
    ss.setPosition 0
    if count == 1:
      ss.write $tJs
    else:
      for i in 1 .. count:
        ss.write $tJs

  proc read_json_stdlib() {.measure.} =
    ss.setPosition 0
    if count == 1:
      discard parseJson(ss.readStr jsSize).isNil
    else:
      for i in 1 .. count:
        discard parseJson(ss.readStr jsSize).isNil

benchmark cfg:
  var
    ss = newStringStream()

  proc write_json_frosty() {.measure.} =
    ss.writeSomething tJs

  proc read_json_frosty() {.measure.} =
    let r = ss.readSomething tJs
