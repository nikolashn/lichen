module interpreter;

import std.algorithm : all, map;
import std.array : array;
import std.conv : to;
import std.stdio : writeln;
import std.sumtype;

import lexer : TokenException;
import syntax;
import parser;
import set;
import env;
import formula;
import pattern;

static void interpret(Stmt[] program) @safe {
  Env env;

  foreach (stmt; program) {
    stmt.val.match!(
      (Expr* e) {
        eval(e, env).interpretValue(stmt);
      },
      (Def* d) {
        (*d).match!(
          (DefineVar dv) {
            env = env.updated(dv.name, eval(dv.rhs, env));
          },
          (DefinePattern dp) {
            env = env.updated(
              dp.name,
              new Value(
                Pattern(dp.params, dp.rhs, env, stmt.line, stmt.col, stmt.path)
              )
            );
          }
        );
      }
    );
  }
}

static void interpretValue(const Value* v, Stmt stmt) @safe {
  (*v).match!(
    (Set s) => s.writeln,
    (bool b) {
      if (!b) {
        stmt.path is null
          ? writeln("Assertion failed on line ", stmt.line, ":", stmt.col)
          : writeln("Assertion failed at path '", stmt.path, "' on line ",
              stmt.line, ":", stmt.col);
      }
    },
    (Pattern p) => p.call([]).interpretValue(stmt)
  );
}

static Value* eval(const Expr* e, const Env env, bool resolvePatterns = true)
  pure @safe
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
              "expression must be a logical expression", e.line, e.col, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          return new Value(!b1);

        case UnOp.Type.UNION:
          if (!v1.isSet) {
            throw new TokenException("The operand of a union expression " ~
              "must be a set", e.line, e.col, e.path);
          }

          auto s1 = (*v1).get!(const Set);
          return new Value(s1.setUnion);

        case UnOp.Type.POWERSET:
          if (!v1.isSet) {
            throw new TokenException("The operand of a power set expression " ~
              "must be a set", e.line, e.col, e.path);
          }

          auto s1 = (*v1).get!(const Set);
          return new Value(Set.makePowerSet(s1));
          
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
              e.line, e.col, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.equals(set2));

        case BinOp.Type.MEMBER:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException(
              "Both sides of a membership test must be sets",
              e.line, e.col, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.member(set2));

        case BinOp.Type.NEQUAL:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException("Both sides of an inequality must be sets",
              e.line, e.col, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(!set1.equals(set2));

        case BinOp.Type.SUBSET:
          if (!v1.isSet || !v2.isSet) {
            throw new TokenException(
              "Both sides of an subset test must be sets",
              e.line, e.col, e.path);
          }

          auto set1 = (*v1).get!Set;
          auto set2 = (*v2).get!Set;
          return new Value(set1.subset(set2));

        case BinOp.Type.LAND:
          if (!v1.isBool || !v2.isBool) {
            throw new TokenException(
              "Both sides of a logical AND expression and must be " ~ 
              "logical expressions", e.line, e.col, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          auto b2 = (*v2).get!(const bool);
          return new Value(b1 && b2);

        case BinOp.Type.LOR:
          if (!v1.isBool || !v2.isBool) {
            throw new TokenException(
              "Both sides of a logical OR expression and must be " ~ 
              "logical expressions", e.line, e.col, e.path);
          }

          auto b1 = (*v1).get!(const bool);
          auto b2 = (*v2).get!(const bool);
          return new Value(b1 || b2);

        default: assert(false);
      }
    },
    (Variable var) {
      auto v1 = env.find(var.name, e.line, e.col, e.path);
      return (*v1).match!(
        (Pattern p) {
          if (!resolvePatterns)
            return new Value(p);

          if (p.paramCount != 0) {
            throw new TokenException(
              "Pattern called with 0 arguments instead of expected " ~ 
              to!string(p.paramCount),
              e.line, e.col, e.path
            );
          }

          return p.call([]);
        },
        _ => v1
      );
    },
    (Finite s) {
      auto vs = s.members.map!(e1 => eval(e1, env));

      if (!vs.all!isSet)
        throw new TokenException("Sets may only contain other sets",
          e.line, e.col, e.path);

      auto sets = vs.map!(v => (*v).get!Set).array;
      return new Value(new Set(sets));
    },
    (ForAll q) {
      auto v1 = eval(q.domain, env);

      if (!v1.isSet)
        throw new TokenException("Domain of a quantification must be a set",
          e.line, e.col, e.path);

      auto dom = (*v1).get!Set;
      return new Value(dom.forAll(q.var, Formula(q.formula, env)));
    },
    (Specific s) {
      auto v1 = eval(s.domain, env);

      if (!v1.isSet)
        throw new TokenException("Domain of a specification must be a set",
          e.line, e.col, e.path);

      auto dom = (*v1).get!Set;
      return new Value(new Set(dom, s.var, Formula(s.formula, env)));
    },
    (Call c) => (*eval(c.callee, env, resolvePatterns : false)).match!(
      (Pattern p) {
        if (!p.fitsParams(c.args)) {
          throw new TokenException(
            "Pattern called with " ~ to!string(c.args.length) ~ 
            (c.args.length == 1 ? " argument" : " arguments") ~
            " instead of expected " ~ to!string(p.paramCount),
            e.line, e.col, e.path
          );
        }
        return 
          resolvePatterns ? p.call(c.args.map!(a => eval(a, env)).array) 
                          : new Value(p);
      },
      _ => throw new TokenException(
        "Only patterns can be called with arguments",
        e.line, e.col, e.path
      )
    ),
    (Set s) => new Value(s)
  );
}

static bool isSet(Value* v) pure nothrow @safe {
  return (*v).has!(const Set);
}

static bool isBool(Value* v) pure nothrow @safe {
  return (*v).has!(const bool);
}

