module parser;

import std.array;
import std.sumtype;
import std.typecons;

import std.stdio; /+ For debugging +/

import lexer;
import syntax;

/+ Syntax:

   program -> { expr ";" | def }
   def -> identifier ":=" expr
   expr -> term ("=" expr)?
   term -> "0" | identifier
 +/

class SyntaxException : Exception { this() pure nothrow @safe { super(""); } }
class EOFException : Exception { this() pure nothrow @safe { super(""); } }

private class Parser {
  private immutable(Token)[] tokens;
  private size_t index;
  private size_t[] tracks;

  this(immutable(Token)[] ts) pure nothrow @safe { tokens = ts; }

  bool done() pure nothrow @safe const {
    return index >= tokens.length;
  }

  bool consume(Token token) pure @safe {
    if (done) throw new EOFException;

    if (token == tokens[index]) {
      debug writeln("Consumed ", token, " at index ", index);
      index += 1;
      return true;
    }
    return false;
  }

  string consumeIdentifier() pure @safe {
    if (done) throw new EOFException;

    auto x = tokens[index].getIdentifier;

    if (x !is null) {
      debug writeln("Consumed identifier ", x, " at index ", index);
      index += 1;
      return x;
    }

    return null;
  }

  /+ TODO: Keeping track (haha) of these will eventually become like a
     malloc-free situation so make an abstraction that hides them.

     Currently, for every parse function, the stack of tracks when the function
     is called must be equal to when it returns.

     Use immutable parsers that are passed around instead +/

  void track() pure nothrow @safe {
    tracks ~= index;
  }

  void untrack() pure nothrow @safe
    in (tracks.length > 0)
  {
    tracks.popBack;
  }

  void backtrack() pure nothrow @safe
    in (tracks.length > 0)
  {
    index = tracks.back;
    tracks.popBack;
    debug writeln("Backtracked to index ", index);
  }
}

Program parse(immutable(Token)[] tokens) pure @safe {
  auto p = new Parser(tokens);

  Program program;

  while (!p.done) {
    p.track;
    auto expr = pExpr(p);

    if (!expr.isNull && p.consume(Token(';'))) {
      program ~= Stmt(expr.get);
      p.untrack;
      continue;
    }

    p.backtrack;

    p.track;
    auto def = pDef(p);

    if (!def.isNull) {
      program ~= Stmt(def.get);
      p.untrack;
      continue;
    }

    p.backtrack;
    throw new SyntaxException;
  }

  return program;
}

Nullable!Def pDef(Parser p) pure @safe {
  p.track;
  auto expr = pExpr(p);

  if (!expr.isNull) {
    auto x = expr.get.match!(
      (Variable v) => v.name,
      _ => null
    );

    if (x !is null && p.consume(Token(Token.Special.DEFINE))) {
      auto expr1 = pExpr(p);

      if (!expr1.isNull && p.consume(Token(';'))) {
        p.untrack;
        return Def(new DefineVar(x, expr1.get)).nullable;
      }
    }
  }

  p.backtrack;
  return Nullable!Def.init;
}

Nullable!Expr pExpr(Parser p) pure @safe {
  p.track;
  auto term = pTerm(p);

  if (!term.isNull) {
    if (p.consume(Token('='))) {
      auto expr = pExpr(p);

      if (!expr.isNull) {
        return Expr(new Equals(term.get, expr.get)).nullable;
      }
    }
    else {
      p.untrack;
      return term.get.nullable;
    }
  }

  p.backtrack;
  return Nullable!Expr.init;
}

Nullable!Expr pTerm(Parser p) pure @safe {
  if (p.consume(Token('0'))) {
    return Expr(new Zero).nullable;
  }
  
  auto x = p.consumeIdentifier;
  if (x !is null) {
    return Expr(new Variable(x)).nullable;
  }

  return Nullable!Expr.init;
}

