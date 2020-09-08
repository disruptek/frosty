# frosty

[![Test Matrix](https://github.com/disruptek/frosty/workflows/CI/badge.svg)](https://github.com/disruptek/frosty/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/frosty?style=flat)](https://github.com/disruptek/frosty/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.0.8%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/frosty?style=flat)](#license)
[![buy me a coffee](https://img.shields.io/badge/donate-buy%20me%20a%20coffee-orange.svg)](https://www.buymeacoffee.com/disruptek)

Serialize native Nim objects to strings, streams, or sockets.

## Goals

Making some assumptions (ie. that our types aren't changing) allows...

- predictably fast performance
- predictably mild memory behavior
- predictably _idiomatic_ API
- **hard to misuse**

## Performance

Frosty _can_ handle cyclic data structures, but **not** memory graphs
of extreme size -- you can exhaust the stack because our traversal is
implemented via recursion. This will be solved soon. [Benchmarks are available
below.](https://github.com/disruptek/frosty#benchmarks).

## Example

It currently looks like this:

```nim
import frosty

var
  data = someArbitraryDataFactory()
  handle = openFileStream("somefile", fmWrite)
freeze(data, handle)
close handle
```

and then

```nim
import frosty

var
  data: SomeArbitraryType
  handle = openFileStream("somefile", fmRead)
thaw(handle, data)
close handle
```

or simply

```nim
import frosty

var brrr = freeze("my data")
assert thaw[string](brrr) == "my data"
```

## Benchmarks

[The source to the benchmark is found in the tests directory.](https://github.com/disruptek/frosty/blob/master/tests/bench.nim)

![benchmarks](docs/bench.svg "benchmarks")


## Installation

```
$ nimph clone disruptek/frosty
```
or if you're still using Nimble like it's 2012,
```
$ nimble install https://github.com/disruptek/frosty
```

## Documentation

[The documentation employs Nim's `runnableExamples` feature to
ensure that usage examples are guaranteed to be accurate. The
documentation is rebuilt during the CI process and hosted on
GitHub.](https://disruptek.github.io/frosty/frosty.html)

## License
MIT
