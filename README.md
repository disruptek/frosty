# marsh
marshal native Nim objects via streams

- `cpp +/ nim-1.0` [![Build Status](https://travis-ci.org/disruptek/marsh.svg?branch=master)](https://travis-ci.org/disruptek/marsh)
- `arc +/ cpp +/ nim-1.3` [![Build Status](https://travis-ci.org/disruptek/marsh.svg?branch=devel)](https://travis-ci.org/disruptek/marsh)

## Goals
- predictably fast performance
- predictably mild memory behavior
- predictably _idiomatic_ API
- **hard to misuse**

## Installation

```
$ nimph clone disruptek/marsh
```
or if you're still using Nimble like it's 2012,
```
$ nimble install https://github.com/disruptek/marsh
```

## Documentation

I'm going to try a little harder with these docs by using `runnableExamples`
so the documentation demonstrates _current_ usage examples and working tests
despite the rapidly-evolving API.

[See the documentation for the marsh module as generated directly from the
source.](https://disruptek.github.io/marsh/marsh.html)

## License
MIT
