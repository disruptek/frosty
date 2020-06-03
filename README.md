# frosty
_experimental_ native Nim blobs via streams, sockets

_it's like Python's pickle, but, y'know, **cooler**_

Actually, it's not.  I don't know why I said that.

- `cpp +/ nim-1.0` [![Build Status](https://travis-ci.org/disruptek/frosty.svg?branch=master)](https://travis-ci.org/disruptek/frosty)
- `arc +/ cpp +/ nim-1.3` [![Build Status](https://travis-ci.org/disruptek/frosty.svg?branch=devel)](https://travis-ci.org/disruptek/frosty)

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

### Stream

Pretty fast.

### Socket

Untested.  Ask @zedeus.

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

_WIP_

I'm going to try a little harder with these docs by using `runnableExamples`
so the documentation demonstrates _current_ usage examples and working tests
despite the rapidly-evolving API.

[See the documentation for the frosty module as generated directly from the
source.](https://disruptek.github.io/frosty/frosty.html)

## Testing

There's a test and a benchmark under `tests/`; the benchmark requires
[criterion](https://disruptek.github.io/criterion).

## License
MIT
