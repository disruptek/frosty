# frosty
_experimental_ marshalling of native Nim objects via streams, channels, sockets

_it's like Python's pickle, but, y'know, **cooler**_

- `cpp +/ nim-1.0` [![Build Status](https://travis-ci.org/disruptek/frosty.svg?branch=master)](https://travis-ci.org/disruptek/frosty)
- `arc +/ cpp +/ nim-1.3` [![Build Status](https://travis-ci.org/disruptek/frosty.svg?branch=devel)](https://travis-ci.org/disruptek/frosty)

## Goals

Making some assumptions (ie. that our types aren't changing) allows...

- predictably fast performance
- predictably mild memory behavior
- predictably _idiomatic_ API
- **hard to misuse**

Crude though it may be, this code reads and writes >500mb of arbitrary Nim data
structures in 1.5s on my machine.

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
var
  data = "my data"
  brrr = freeze(data)
  ahha = thaw[string](brrr)
assert ahha == data
```

Zevv gave me the idea to provide a `channels` API as well, so that's something
to add next. Channels are kinda expensive by comparison, though, because they
require a copy...

## Installation

```
$ nimph clone disruptek/frosty
```
or if you're still using Nimble like it's 2012,
```
$ nimble install https://github.com/disruptek/frosty
```

## Documentation

_WIP_

I'm going to try a little harder with these docs by using `runnableExamples`
so the documentation demonstrates _current_ usage examples and working tests
despite the rapidly-evolving API.

[See the documentation for the frosty module as generated directly from the
source.](https://disruptek.github.io/frosty/frosty.html)

## License
MIT
