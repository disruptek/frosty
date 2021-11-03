# frosty

[![Test Matrix](https://github.com/disruptek/frosty/workflows/CI/badge.svg)](https://github.com/disruptek/frosty/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/frosty?style=flat)](https://github.com/disruptek/frosty/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.5.1%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/frosty?style=flat)](#license)
[![Matrix](https://img.shields.io/badge/chat-on%20matrix-brightgreen)](https://matrix.to/#/#disruptek:matrix.org)

Serialize native Nim types to strings, streams, sockets, or anything else.

## Support

- references
- distincts
- cycles
- inheritance
- variants
- `gc:arc`
- `gc:orc`
- ~`gc:refc`~
- ~`c++`~
- [for broader support, use a prior frosty](https://github.com/disruptek/frosty/tree/v1)

## Usage

There are two operations: `freeze` and `thaw`.

Each takes as input a _target_ and the _data_ to serialize or deserialize.

### `freeze` Serializes Any Data to the Target

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

### `thaw` Deserializes Any Data From the Target

This example uses the `frosty/streams` target supplied in this repository.

```nim
import frosty/streams

var
  data: MyObject
  handle = openFileStream("somefile", fmRead)
# read deserialized data from the file stream
thaw(handle, data)
assert data == MyObject(x: 4, y: "three")
close handle
```

### Easily Customize Serialization for Types

If you want to alter the serialization for a type, simply implement `serialize`
and `deserialize` procedures for your type.

```nim
proc serialize*[S](output: var S; login: LoginCredentials) =
  ## avoid accidentally serializing passwords
  serialize(output, login.username)

proc deserialize*[S](input: var S; login: var LoginCredentials) =
  login.password = "{scrubbed}"
  deserialize(input, login.username)
```

### Easily Implement Your Own Custom Targets

You merely provide two forms of reading and writing for your target -- simple
types such as ordinals or floats, and strings, for which you are additionally
provided a length argument for your convenience.

This is an implementation of a `Stream` target.

```nim
import frosty
export frosty

proc serialize*(output: var Stream; input: string; length: int) =
  write(output, input)

proc deserialize*(input: var Stream; output: var string; length: int) =
  readStr(input, length, output)

proc serialize*[T](output: var Stream; input: T) =
  write(output, input)

proc deserialize*[T](input: var Stream; output: var T) =
  read(input, output)
```

### Adhoc Serialization To/From Strings

The `frosty/streams` module also provides an even simpler `freeze` and `thaw`
API that uses `StringStream` to provide basic string-based input and output.

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
