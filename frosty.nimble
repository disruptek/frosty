version = "0.4.6"
author = "disruptek"
description = "serialize native Nim types to strings, streams, or sockets"
license = "MIT"

when defined(frostySorted):
  requires "https://github.com/narimiran/sorta < 1.0.0"
when not defined(release):
  requires "https://github.com/disruptek/criterion < 1.0.0"
  requires "https://github.com/disruptek/balls > 2.0.0 & < 3.0.0"

task test, "run unit tests":
  when defined(windows):
    exec "balls.cmd"
  else:
    exec "balls"

task demo, "generate benchmark":
  exec """demo docs/bench.svg "nim c --out=\$1 --gc:arc --define:danger tests/bench.nim""""
