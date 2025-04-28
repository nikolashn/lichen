module formula;

import std.conv;
import std.sumtype;

import syntax;
import env;
import set;
import interpreter;

const struct Formula {
  Expr* expr;
  size_t freshCount;
  private Env env;

  this(const Expr* e, const Env s, const size_t n = 0) 
    pure nothrow @safe const
  {
    expr = e; env = s; freshCount = n;
  }

  bool toBool() pure @safe const {
    return (*eval(expr, env)).get!(const bool);
  }

  string toString() pure nothrow @safe const {
    return expr.toString;
  }

  /+ Substitute instances of a free variable for set +/
  Formula sub(const Variable var, Set set) pure nothrow @safe const {
    return Formula(expr, env.updated(var.name, new Value(set)));
  }

  /+ Rename old free variable to new (fresh) variable. +/
  Formula rename(const Variable oldVar, const Variable newVar)
    pure nothrow @safe const
  {
    auto expr1 = expr.rename(oldVar, newVar);
    /+ If env has a delete method, use env.delete(oldVar) instead +/
    return Formula(expr1, env);
  }

  /+ Change the expression of the formula while preserving the environment +/
  Formula reformulate(const Expr* e) pure nothrow @safe const {
    return Formula(e, env);
  }
}

/+ Fresh variable names begin with a leading sigil. +/
static Variable makeFresh(const size_t n) pure nothrow @safe {
  return Variable("$" ~ to!string(n + 1));
}

