module interpreter;

import std.stdio;
import std.sumtype;

import syntax;
import parser;

class Set {
  private immutable bool isZero;

  this() pure nothrow @safe const { isZero = true; }

  override string toString() pure nothrow @safe const {
    if (isZero) return "0";
    return "[set]";
  }

  bool equals(const Set o) pure nothrow @safe const {
    return isZero && o.isZero;
  }
}

alias Value = SumType!(Set, bool);

struct Env {
  private const(Value)*[string] entries;

  const(Value*) find(const string x) pure @safe const {
    if (x !in entries)
      throw new SemanticException("Used undefined identifier '" ~ x ~ "'");
    return entries[x];
  }

  void update(const string x, const Value* v) pure nothrow @safe {
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
        const Value v = *eval(e, env);
        v.match!(
          (const Set s) => s.writeln,
          (const bool b) {
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

static const(Value)* eval(const Expr* e, const Env env) pure @safe
  in (e !is null)
  out (v; v !is null)
{
  return (*e).match!(
    (Zero _) => new Value(new Set),
    (Equals e1) {
      auto v1 = eval(e1.lhs, env);
      auto v2 = eval(e1.rhs, env);

      if (!v1.isSet || !v2.isSet) 
        throw new SemanticException("Both sides of an equality must be sets");

      return (*v1).match!(
        (const Set s1) => (*v2).match!(
          (const Set s2) => new Value(s1.equals(s2)),
          _ => assert(0)
        ),
        _ => assert(0)
      );
    },
    (Variable v) => env.find(v.name)
  );
}

static bool isSet(const Value* v) pure nothrow @safe {
  return (*v).match!(
    (const Set s) => true,
    _ => false
  );
}

