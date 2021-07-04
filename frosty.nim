{.push hint[XDeclaredButNotUsed]: off.}
when false:
  import frosty/streams
  import frosty/net
  from frosty/spec import FreezeError, ThawError
else:
  import frosty/spec
export freeze, thaw, FreezeError, ThawError
{.pop.}
