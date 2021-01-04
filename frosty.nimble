version = "1.0.0"
author = "disruptek"
description = "serialize native Nim types to strings, streams, or sockets"
license = "MIT"

requires "https://github.com/disruptek/cps < 1.0.0"

when defined(frostySorted):
  requires "https://github.com/narimiran/sorta < 1.0.0"

when not defined(release):
  requires "https://github.com/disruptek/criterion < 1.0.0"
  requires "https://github.com/disruptek/testes >= 0.8.0 & < 1.0.0"

task test, "run unit tests":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec "testes"

task demo, "generate benchmark":
  exec """demo docs/bench.svg "nim c --out=\$1 --gc:arc --define:danger tests/bench.nim""""
