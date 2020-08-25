# frosty

[![Test Matrix](https://github.com/disruptek/frosty/workflows/CI/badge.svg)](https://github.com/disruptek/frosty/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/frosty?style=flat)](https://github.com/disruptek/frosty/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.0.8%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/frosty?style=flat)](#license)

Serialize native Nim objects via Streams, Sockets.  That is all.

## Goals

Making some assumptions (ie. that our types aren't changing) allows...

- predictably fast performance
- predictably mild memory behavior
- predictably _idiomatic_ API
- **hard to misuse**

## Performance

Frosty can handle cyclic data structures, but not (yet) memory graphs of
infinite size -- you can exhaust the stack. We have a solution for this in the
works.

## Example

It currently looks like this:

```nim
import frosty

var
  data = someArbitraryDataFactory()
  handle = openFileStream("somefile", fmWrite)
data.freeze(handle)
handle.close
```

and then

```nim
import frosty

var
  data: SomeArbitraryType
  handle = openFileStream("somefile", fmRead)
handle.thaw(data)
handle.close
```

Or simply

```nim
import frosty

var brrr = freeze("my data")
assert thaw[string](brrr) == "my data"
```

## Installation

```
$ nimph clone disruptek/frosty
```
or if you're still using Nimble like it's 2012,
```
$ nimble install https://github.com/disruptek/frosty
```

## Documentation

I'm going to try a little harder with these docs by using `runnableExamples`
so the documentation demonstrates _current_ usage examples and working tests
despite the rapidly-evolving API.

[See the documentation for the frosty module as generated directly from the
source.](https://disruptek.github.io/frosty/frosty.html)

## Testing

There's a test and [a benchmark under `tests/`](https://github.com/disruptek/frosty/blob/master/tests/bench.nim); the benchmark requires
[criterion](https://github.com/disruptek/criterion).

## License
MIT
