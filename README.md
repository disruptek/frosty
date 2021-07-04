# frosty

[![Test Matrix](https://github.com/disruptek/frosty/workflows/CI/badge.svg)](https://github.com/disruptek/frosty/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/frosty?style=flat)](https://github.com/disruptek/frosty/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.0.8%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/frosty?style=flat)](#license)
[![buy me a coffee](https://img.shields.io/badge/donate-buy%20me%20a%20coffee-orange.svg)](https://www.buymeacoffee.com/disruptek)
[![Matrix](https://img.shields.io/matrix/disruptek:matrix.org?style=flat&logo=matrix)](https://matrix.to/#/#disruptek:matrix.org)

Serialize native Nim types to strings, streams, or sockets.

## Usage

There are two operations: `freeze` and `thaw`.

#### `freeze[T](output: Socket or Stream or var string; input: T)`
```nim
import frosty

var
  data = someArbitraryDataFactory()
  handle = openFileStream("somefile", fmWrite)
# write serialized data into the file handle
freeze(handle, data)
close handle
```

#### `thaw[T](input: Socket or Stream or string; output: var T)`
```nim
import frosty

var
  data: SomeArbitraryType
  handle = openFileStream("somefile", fmRead)
# read deserialized data from the file handle
thaw(handle, data)
close handle
```

#### `freeze[T](input: T): string`
#### `thaw[T](input: Socket or Stream or string): T`
```nim
import frosty

# adhoc serialization and deserialization
var brrr = freeze("my data")
assert thaw[string](brrr) == "my data"
```

## Performance

Frosty _can_ handle cyclic data structures.

### Benchmark vs. Flatty

[The source to the following benchmark is found in the tests directory.](https://github.com/disruptek/frosty/blob/master/tests/bench.nim)

The benchmark compares frosty to https://github.com/treeform/flatty for a few
static datatypes -- flatty does not work with cast objects yet.

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
