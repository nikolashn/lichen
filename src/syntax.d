module syntax;

import std.algorithm : map;
import std.array : array;
import std.sumtype;
import std.typecons : Tuple;

import foldconst;
import set;
import formula;

/+ Statements +/

struct Stmt {
  alias Type = SumType!(Expr*, Def*);
  Type val;
  size_t line, col;
  string path;

  this(Expr* e) pure nothrow @safe { val = e; }
  this(Def* d) pure nothrow @safe { val = d; }
}

/+ Expressions +/

struct Expr {
  alias Type = SumType!(
    Zero,
    UnOp,
    BinOp,
    Variable,
    Finite,
    ForAll,
    Specific,
    Set
  );
  Type val;
  size_t line, col;
  string path;

  this(Zero x) pure nothrow @safe { val = x; }
  this(UnOp x) pure nothrow @safe { val = x; }
  this(BinOp x) pure nothrow @safe { val = x; }
  this(Variable x) pure nothrow @safe { val = x; }
  this(Finite x) pure nothrow @safe { val = x; }
  this(ForAll x) pure nothrow @safe { val = x; }
  this(Specific x) pure nothrow @safe { val = x; }
  this(Set x) pure nothrow @safe { val = x; }
  this(Type x) pure nothrow @safe { val = x; }

  string toString() pure nothrow @safe const {
    return val.match!(
      (Zero _) => "0",
      (UnOp x) {
        immutable s = x.post.toString;
        switch (x.type) {
          case UnOp.Type.LNOT: 
            return "~" ~ s;
          case UnOp.Type.UNION:
            return "U" ~ s;
          case UnOp.Type.POWERSET:
            return "P(" ~ s ~ ")";
          default: assert(false);
        }
      },
      (BinOp x) {
        immutable l = x.lhs.toString, r = x.rhs.toString;
        switch (x.type) {
          case BinOp.Type.EQUALS: 
            return l ~ " = " ~ r;
          case BinOp.Type.MEMBER:
            return l ~ " < " ~ r;
          case BinOp.Type.NEQUAL:
            return l ~ " /= " ~ r;
          case BinOp.Type.SUBSET:
            return l ~ " sub " ~ r;
          case BinOp.Type.LAND:
            return "(" ~ l ~ " & " ~ r ~ ")";
          case BinOp.Type.LOR:
            return "(" ~ l ~ " | " ~ r ~ ")";
          default: assert(false);
        }
      },
      (Variable x) => x.name,
      (Finite x) => "{" ~ x.members.map!(e => e.toString).array.foldl1!(
          (str, e) => str ~ ", " ~ e
        ) ~ "}",
      (ForAll x) => "all " ~ x.var.name ~ 
        "(" ~ x.domain.toString ~ ") " ~ x.formula.toString,
      (Specific x) => "{" ~ x.var.name ~ " < " ~ 
        x.domain.toString ~ " : " ~ x.formula.toString ~ "}",
      (Set x) => x.toString
    );
  }

  const Expr* rename(const Variable oldVar, const Variable newVar) 
    pure nothrow @safe 
  {
    return val.match!(
      (UnOp x) {
        switch (x.type) {
          case UnOp.Type.LNOT, UnOp.Type.UNION, UnOp.Type.POWERSET:
          {
            return new Expr(UnOp(x.type, x.post.rename(oldVar, newVar)));
          }
          default: assert(false);
        }
      },
      (BinOp x) {
        switch (x.type) {
          case BinOp.Type.EQUALS, BinOp.Type.MEMBER, BinOp.Type.NEQUAL,
               BinOp.Type.SUBSET, BinOp.Type.LAND, BinOp.Type.LOR:
          {
            return new Expr(BinOp(x.type, 
              x.lhs.rename(oldVar, newVar), x.rhs.rename(oldVar, newVar)));
          }
          default: assert(false);
        }
      },
      (Variable x) => 
        (x.name == oldVar.name) ? new Expr(newVar) : new Expr(x),
      (Finite x) => new Expr(Finite(
        x.members.map!(e => e.rename(oldVar, newVar)).array
      )),
      _ => new Expr(val)
    );
  }
}

struct Zero { }

struct UnOp {
  enum Type {
    LNOT,
    UNION,
    POWERSET
  }

  const Type type;
  const Expr* post;

  this(const Type t, const Expr* e1) pure nothrow @safe {
    type = t; post = e1;
  }
}

struct BinOp {
  enum Type {
    EQUALS,
    MEMBER,
    NEQUAL,
    SUBSET,
    LAND,
    LOR
  }

  const Type type;
  const Expr* lhs, rhs;

  this(const Type t, const Expr* e1, const Expr* e2) pure nothrow @safe {
    type = t; lhs = e1; rhs = e2;
  }
}

static Expr* makeImpliesExpr(const Expr* e1, const Expr* e2) 
  pure nothrow @safe
{
  return new Expr(BinOp(BinOp.Type.LOR,
    new Expr(UnOp(UnOp.Type.LNOT, e1)),
    e2
  ));
}

struct Variable {
  const string name;
  this(string x) pure nothrow @safe { name = x; }
}

struct Finite {
  const Expr*[] members;
  this(const Expr*[] es) pure nothrow @safe
    in (es.length > 0)
  {
    members = es;
  }
}

struct ForAll {
  const Variable var;
  const Expr* domain, formula;

  this(const Variable v, const Expr* e1, const Expr* e2) pure nothrow @safe {
    var = v; domain = e1; formula = e2;
  }
}

static Expr* makeExistsExpr(
    const Variable var, 
    const Expr* domain, 
    const Expr* formula
  ) 
  pure nothrow @safe
{
  return new Expr(UnOp(UnOp.Type.LNOT,
    new Expr(ForAll(var, domain,
      new Expr(UnOp(UnOp.Type.LNOT, formula))
    ))
  ));
}

struct Specific {
  const Variable var;
  const Expr* domain, formula;

  this(const Variable v, const Expr* e1, const Expr* e2) pure nothrow @safe {
    var = v; domain = e1; formula = e2;
  }
}

/+ Definitions +/

alias Def = SumType!(
  DefineVar
);

alias DefineVar = Tuple!(string, "lhs", Expr*, "rhs");

