module syntax;

import std.sumtype;

/+ Program +/

alias Program = Stmt[];

/+ Statements +/

alias Stmt = SumType!(Expr, Def);

/+ Expressions +/

alias Expr = SumType!(Zero, Equals, Variable);

class Zero { }

class Equals {
  const Expr lhs, rhs;
  this(const Expr e1, const Expr e2) pure nothrow @safe {
    lhs = e1; rhs = e2;
  }
}

class Variable {
  const string name;
  this(string x) pure nothrow @safe { name = x; }
}

/+ Definitions +/

alias Def = SumType!(DefineVar);

class DefineVar {
  const string var;
  const Expr rhs;
  this(string x, const Expr e2) pure nothrow @safe {
    var = x; rhs = e2;
  }
}

