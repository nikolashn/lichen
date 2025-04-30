module pattern;

import std.array : array;
import std.range : iota;
import std.typecons : Nullable;

import fold;
import lexer : TokenException;
import syntax;
import env;
import interpreter : eval;

const struct Pattern {
  size_t paramCount;

  private string[] params;
  private Expr* expr;
  private Env env;

  this(
      const string[] ss,
      const Expr* e,
      const Env r,
      const size_t line,
      const size_t col, 
      const string path
    ) 
    pure @safe const 
  { 
    if (!ss.getDuplicate.isNull) {
      throw new TokenException(
        "Parameter list for pattern cannot contain duplicates",
        line, col, path);
    }
    params = ss; paramCount = ss.length; expr = e; env = r;
  }

  bool fitsParams(T)(const T[] args) pure nothrow @safe const {
    return paramCount == args.length;
  }

  const(Value)* call(const Value*[] args) pure @safe const
    in (fitsParams(args))
  {
    auto newEnv = foldl!((r, i) => r.updated(params[i], args[i]))
                        (env, iota(paramCount).array);
    return eval(expr, newEnv);
  }
}

template getDuplicate(T) {
  /+ Check for duplicates in linear time.
     Parameters: r - range to be checked for duplicates
     Returns: value of a duplicate if it exists, null otherwise +/
  const(Nullable!T) getDuplicate(const T[] r) pure nothrow @safe {
    bool[T] hasElem;
    foreach (elem; r) {
      if ((elem in hasElem) !is null)
        return const(Nullable!T)(elem);
      hasElem[elem] = true;
    }
    return Nullable!T.init;
  }
}
