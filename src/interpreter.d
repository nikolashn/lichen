module interpreter;

import std.stdio;
import std.sumtype;

import syntax;
import parser;
import set;

alias Value = const SumType!(Set, bool);

struct Env {
  private Value*[string] entries;

  Value* find(const string x) pure @safe const {
    if (x !in entries)
      throw new SemanticException("Used undefined identifier '" ~ x ~ "'");
    return entries[x];
  }

  void update(const string x, Value* v) pure nothrow @safe {
    entries[x] = v;
  }
}

class SemanticException : Exception {
  this(string s) pure nothrow @safe { super(s); }
}

static void interpret(Stmt[] program) @safe {
  Env env;

  foreach (stmt; program) {
    stmt.match!(
      (Expr* e) {
        auto v = *eval(e, env);
        v.match!(
          (Set s) => s.writeln,
          (bool b) {
            if (!b) "Assertion failed".writeln;
          }
        );
      },
      (Def* d) {
        (*d).match!(
          (DefineVar dv) => env.update(dv.lhs, eval(dv.rhs, env))
        );
      }
    );
  }
}

static Value* eval(const Expr* e, const Env env) pure @safe
  in (e !is null)
  out (v; v !is null)
{
  return (*e).match!(
    (Zero _) => new Value(new Set),
    (BinOp e1) {
      auto v1 = eval(e1.lhs, env);
      auto v2 = eval(e1.rhs, env);
      auto op = e1.type;

      switch (op) {
        case BinOp.Type.EQUALS:
          if (!v1.isSet || !v2.isSet) {
            throw new SemanticException(
              "Both sides of an equality must be sets");
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.equals(set2));

        case BinOp.Type.MEMBER:
          if (!v1.isSet || !v2.isSet) {
            throw new SemanticException(
              "Both sides of a membership test must be sets");
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.member(set2));

        case BinOp.Type.NEQUAL:
          if (!v1.isSet || !v2.isSet) {
            throw new SemanticException(
              "Both sides of an inequality must be sets");
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(!set1.equals(set2));

        default: assert(0);
      }
    },
    (Variable var) => env.find(var.name),
    (Single s) {
      auto v = eval(s.member, env);

      if (!v.isSet)
        throw new SemanticException("Sets may only contain other sets");

      auto set = (*v).get!Set;
      return new Value(new Set(set));
    },
    (Pair s) {
      auto v1 = eval(s.member1, env);
      auto v2 = eval(s.member2, env);

      if (!v1.isSet || !v2.isSet)
        throw new SemanticException("Sets may only contain other sets");

      auto set1 = (*v1).get!Set;
      auto set2 = (*v2).get!Set;
      return new Value(new Set(set1, set2));
    }
  );
}

static bool isSet(Value* v) pure nothrow @safe {
  return (*v).has!(const Set);
}

