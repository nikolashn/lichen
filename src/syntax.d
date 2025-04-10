module syntax;

import std.sumtype;

/+ Program +/

alias Program = Stmt[];

/+ Statements +/

alias Stmt = SumType!(Expr, Def);

/+ Expressions +/

alias Expr = SumType!(Empty, Equals, Variable);

class Empty { }

class Equals {
  immutable Expr lhs, rhs;
  this(immutable Expr e1, immutable Expr e2) pure nothrow @safe {
    lhs = e1; rhs = e2;
  }
}

class Variable {
  immutable string name;
  this(string x) pure nothrow @safe { name = x; }
}

/+ Definitions +/

alias Def = SumType!(DefineVar);

class DefineVar {
  immutable string var;
  immutable Expr rhs;
  this(string x, immutable Expr e2) pure nothrow @safe {
    var = x; rhs = e2;
  }
}

