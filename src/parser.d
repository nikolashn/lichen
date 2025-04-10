module parser;

import std.array;
import std.sumtype;

import std.stdio; /+ For debugging +/

import lexer;
import syntax;

/+ Syntax:

   program -> { expr ";" | def }
   def -> identifier ":=" expr ";"
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

static Stmt[] parse(immutable(Token)[] tokens) pure @safe {
  auto p = new Parser(tokens);

  Stmt[] program;

  while (!p.done) {
    p.track;
    auto expr = pExpr(p);

    if (expr !is null && p.consume(Token(';'))) {
      program ~= Stmt(expr);
      p.untrack;
      continue;
    }

    p.backtrack;

    p.track;
    auto def = pDef(p);

    if (def !is null) {
      program ~= Stmt(def);
      p.untrack;
      continue;
    }

    p.backtrack;
    throw new SyntaxException;
  }

  debug writeln("Finished parsing");
  return program;
}

private static Def* pDef(Parser p) pure @safe {
  p.track;
  auto expr = pExpr(p);

  if (expr !is null) {
    string x = (*expr).match!(
      (Variable var) => var.name,
      _ => null
    );

    if (x !is null && p.consume(Token(Token.Special.DEFINE))) {
      auto expr1 = pExpr(p);

      if (expr1 !is null && p.consume(Token(';'))) {
        p.untrack;
        return new Def(DefineVar(x, expr1));
      }
    }
  }

  p.backtrack;
  return null;
}

private static Expr* pExpr(Parser p) pure @safe {
  p.track;
  auto term = pTerm(p);

  if (term !is null) {
    if (p.consume(Token('='))) {
      auto expr = pExpr(p);

      if (expr !is null) {
        return new Expr(Equals(term, expr));
      }
    }
    else {
      p.untrack;
      return term;
    }
  }

  p.backtrack;
  return null;
}

private static Expr* pTerm(Parser p) pure @safe {
  if (p.consume(Token('0'))) {
    return new Expr(Zero());
  }
  
  auto x = p.consumeIdentifier;
  if (x !is null) {
    return new Expr(Variable(x));
  }

  return null;
}

