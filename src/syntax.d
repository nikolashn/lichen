module syntax;

import std.sumtype;
import std.typecons;

/+ Statements +/

alias Stmt = SumType!(Expr*, Def*);

/+ Expressions +/

alias Expr = SumType!(
  Zero,
  BinOp,
  Variable
);

struct Zero { }

struct BinOp {
  enum Type {
    EQUALS,
    MEMBER
  }

  const Type type;
  const Expr* lhs, rhs;

  this(Type t, Expr* e1, Expr* e2) pure nothrow @safe {
    type = t; lhs = e1; rhs = e2;
  }
}

struct Variable {
  const string name;
  this(string x) pure nothrow @safe { name = x; }
}

/+ Definitions +/

alias Def = SumType!(
  DefineVar
);

alias DefineVar = Tuple!(string, "lhs", Expr*, "rhs");

