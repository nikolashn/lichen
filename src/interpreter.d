module interpreter;

import std.stdio;
import std.sumtype;

import lexer;
import syntax;
import parser;
import set;

alias Value = const SumType!(Set, bool);

struct Env {
  private Value*[string] entries;

  Value* find(
      const string x,
      const size_t line,
      const size_t row,
      const string path = null)
    pure @safe const
  {
    if (x !in entries) {
      throw new TokenException("Used undefined identifier '" ~ x ~ "'",
        line, row, path);
    }
    return entries[x];
  }

  void update(const string x, Value* v) pure nothrow @safe {
    entries[x] = v;
  }
}

static void interpret(Stmt[] program) @safe {
  Env env;

  foreach (stmt; program) {
    stmt.val.match!(
      (Expr* e) {
        auto v = *eval(e, env);
        v.match!(
          (Set s) => s.writeln,
          (bool b) {
            if (!b) {
              stmt.path is null
                ? writeln("Assertion failed on line ", stmt.line, ":", stmt.row)
                : writeln("Assertion failed at path '", stmt.path, "' on line ",
                    stmt.line, ":", stmt.row);
            }
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
  return e.val.match!(
    (Zero _) => new Value(new Set),
    (UnOp e1) {
      auto v1 = eval(e1.post, env);
      auto op = e1.type;

      switch (op) {
        case UnOp.Type.LNOT:
          if (!v1.isBool) {
            throw new TokenException("The operand of a logical NOT " ~
              "expression must be a logical expression", e.line, e.row, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          return new Value(!b1);
          
        default: assert(false);
      }
    },
    (BinOp e1) {
      auto v1 = eval(e1.lhs, env);
      auto v2 = eval(e1.rhs, env);
      auto op = e1.type;

      switch (op) {
        case BinOp.Type.EQUALS:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException("Both sides of an equality must be sets",
              e.line, e.row, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.equals(set2));

        case BinOp.Type.MEMBER:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException(
              "Both sides of a membership test must be sets",
              e.line, e.row, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.member(set2));

        case BinOp.Type.NEQUAL:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException("Both sides of an inequality must be sets",
              e.line, e.row, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(!set1.equals(set2));

        case BinOp.Type.LAND:
          if (!v1.isBool || !v2.isBool) {
            throw new TokenException(
              "Both sides of a logical AND expression and must be " ~ 
              "logical expressions", e.line, e.row, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          auto b2 = (*v2).get!(const bool);
          return new Value(b1 && b2);

        case BinOp.Type.LOR:
          if (!v1.isBool || !v2.isBool) {
            throw new TokenException(
              "Both sides of a logical OR expression and must be " ~ 
              "logical expressions", e.line, e.row, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          auto b2 = (*v2).get!(const bool);
          return new Value(b1 || b2);

        default: assert(false);
      }
    },
    (Variable var) => env.find(var.name, e.line, e.row, e.path),
    (Single s) {
      auto v = eval(s.member, env);

      if (!v.isSet)
        throw new TokenException("Sets may only contain other sets",
          e.line, e.row, e.path);

      auto set = (*v).get!Set;
      return new Value(new Set(set));
    },
    (Pair s) {
      auto v1 = eval(s.member1, env);
      auto v2 = eval(s.member2, env);

      if (!v1.isSet || !v2.isSet)
        throw new TokenException("Sets may only contain other sets",
          e.line, e.row, e.path);

      auto set1 = (*v1).get!Set;
      auto set2 = (*v2).get!Set;
      return new Value(new Set(set1, set2));
    }
  );
}

static bool isSet(Value* v) pure nothrow @safe {
  return (*v).has!(const Set);
}

static bool isBool(Value* v) pure nothrow @safe {
  return (*v).has!(const bool);
}

