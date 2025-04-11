module syntax;

import std.sumtype;
import std.typecons;

/+ Statements +/

struct Stmt {
  alias Type = SumType!(Expr*, Def*);
  Type val;
  size_t line, row;
  string path;

  this(Expr* e) pure nothrow @safe { val = e; }
  this(Def* d) pure nothrow @safe { val = d; }
}

/+ Expressions +/

struct Expr {
  alias Type = SumType!(
    Zero,
    BinOp,
    Variable,
    Single,
    Pair
  );
  Type val;
  size_t line, row;
  string path;

  this(Zero x) pure nothrow @safe { val = x; }
  this(BinOp x) pure nothrow @safe { val = x; }
  this(Variable x) pure nothrow @safe { val = x; }
  this(Single x) pure nothrow @safe { val = x; }
  this(Pair x) pure nothrow @safe { val = x; }
}

struct Zero { }

struct BinOp {
  enum Type {
    EQUALS,
    MEMBER,
    NEQUAL
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

struct Single {
  const Expr* member;
  this(Expr* e1) pure nothrow @safe { member = e1; }
}

struct Pair {
  const Expr* member1, member2;
  this(Expr* e1, Expr* e2) pure nothrow @safe {
    member1 = e1; member2 = e2;
  }
}

/+ Definitions +/

alias Def = SumType!(
  DefineVar
);

alias DefineVar = Tuple!(string, "lhs", Expr*, "rhs");

