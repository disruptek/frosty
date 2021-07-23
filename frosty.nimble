version = "1.0.1"
author = "disruptek"
description = "serialize native Nim types to strings, streams, or sockets"
license = "MIT"

when not defined(release):
  requires "https://github.com/disruptek/balls > 2.0.0 & < 4.0.0"

installExt = @["nim"]       # i have no idea why i might need this
skipDirs = @["tests"]       # so stupid...  who doesn't want tests?

task test, "run unit tests":
  # nim bug https://github.com/nim-lang/Nim/issues/16661
  when defined(windows):
    exec "balls.cmd"
  else:
    exec "balls"

task demo, "generate benchmark":
  exec """demo docs/bench.svg "nim c --out=\$1 --gc:arc --define:danger tests/bench.nim""""
