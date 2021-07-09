{.push hint[XDeclaredButNotUsed]: off.}
when true:
  import frosty/spec
else:
  import frosty/spec
export freeze, thaw, FreezeError, ThawError
{.pop.}
