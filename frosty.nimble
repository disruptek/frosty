version = "0.4.4"
author = "disruptek"
description = "serialize native Nim types to strings, streams, or sockets"
license = "MIT"

requires "https://github.com/narimiran/sorta < 1.0.0"
requires "https://github.com/disruptek/criterion < 1.0.0"
requires "https://github.com/disruptek/testes < 1.0.0"

task test, "run unit tests":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec "testes"

task demo, "generate benchmark":
  exec """demo docs/bench.svg "nim c --out=\$1 --gc:arc --define:danger tests/bench.nim""""
