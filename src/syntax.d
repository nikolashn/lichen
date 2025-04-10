module syntax;

import std.sumtype;
import std.typecons;

/+ Statements +/

alias Stmt = SumType!(Expr*, Def*);

/+ Expressions +/

alias Expr = SumType!(
  Zero,
  Equals,
  Variable
);

struct Zero { }
struct Equals {
  const Expr* lhs, rhs;
  this(Expr* e1, Expr* e2) pure nothrow @safe { lhs = e1; rhs = e2; }
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

