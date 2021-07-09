# frosty

[![Test Matrix](https://github.com/disruptek/frosty/workflows/CI/badge.svg)](https://github.com/disruptek/frosty/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/frosty?style=flat)](https://github.com/disruptek/frosty/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.5.1%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/frosty?style=flat)](#license)
[![buy me a coffee](https://img.shields.io/badge/donate-buy%20me%20a%20coffee-orange.svg)](https://www.buymeacoffee.com/disruptek)
[![Matrix](https://img.shields.io/matrix/disruptek:matrix.org?style=flat&logo=matrix)](https://matrix.to/#/#disruptek:matrix.org)

Serialize native Nim types to strings, streams, or sockets.

## Support

- references
- distincts
- cycles
- inheritance
- variants

## Usage

There are two operations: `freeze` and `thaw`.

Each takes as input a _target_ and the _data_ to serialize or deserialize.

#### `freeze` serializes any data to the target

This example uses the `frosty/streams` target supplied in this repository.

```nim
import frosty/streams

type
  MyObject = object
    x: int
    y: string

var
  data = MyObject(x: 4, y: "three")
  handle = openFileStream("somefile", fmWrite)
# write serialized data into the file stream
freeze(handle, data)
close handle
```

#### `thaw` deserializes any data from a target

This example uses the `frosty/streams` target supplied in this repository.

```nim
import frosty/streams

var
  data: MyObject
  handle = openFileStream("somefile", fmRead)
# read deserialized data from the file handle
thaw(handle, data)
assert data == MyObject(x: 4, y: "three")
close handle
```

#### customize serialization for your types

If you want to alter the serialization for a type, simply implement `serialize`
and `deserialize` procedures for your type.

```nim
import frosty

proc serialize*[S](output: var S; input: MyObject) =
  serialize(output, input.y)

proc deserialize*[S](input: var S; output: var MyObject) =
  var mine = MyObject(x: 1)
  serialize(output, mine.y)
```

#### implement your own custom targets

This is the complete implementation for the `frosty/streams` target.

```nim
import frosty

proc serialize*(output: var Streamy; input: string; len: int) =
  write(output, input)

proc deserialize*(input: var Streamy; output: var string; len: int) =
  readStr(input, len, output)

proc serialize*[T](output: var Streamy; input: T) =
  write(output, input)

proc deserialize*[T](input: var Streamy; output: var T) =
  read(input, output)
```

#### adhoc serialization to/from strings

The `frosty/streams` module also provides an even simpler `freeze` and `thaw`
API that uses `StringStream`.

```nim
import frosty/streams

var brrr = freeze MyObject(x: 2, y: "four")
assert thaw[MyObject](brrr) == MyObject(x: 2, y: "four")
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

[The documentation employs Nim's `runnableExamples` feature to
ensure that usage examples are guaranteed to be accurate. The
documentation is rebuilt during the CI process and hosted on
GitHub.](https://disruptek.github.io/frosty/frosty.html)

## License
MIT
