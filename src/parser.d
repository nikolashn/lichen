module parser;

import std.array;
import std.sumtype;

import std.stdio; /+ For debugging +/

import lexer;
import syntax;

/+ Syntax:

   program -> { expr ";" | def }
   def -> identifier ":=" expr ";"
   expr -> term ("=" expr | "<" expr | "/=" expr)?
   term -> "0" | identifier | "{" (expr ("," expr)?)? "}"
 +/

class EOFException : Exception {
  string path;
  this(string path = null) pure nothrow @safe {
    super("Unexpected end of input");
    this.path = path;
  }
}

private class Parser {
  private immutable(Token)[] tokens;
  private size_t index;
  private size_t[] tracks;

  this(immutable(Token)[] ts) pure nothrow @safe {
    tokens = ts;
  }

  bool done() pure nothrow @safe const {
    return index >= tokens.length;
  }

  void throwIfDone() pure @safe const {
    if (done) {
      throw new EOFException(tokens.length > 0 ? tokens.back.path : null);
    }
  }

  Token top() pure @safe const {
    throwIfDone;
    return tokens[index];
  }

  bool consume(Token token) pure @safe {
    throwIfDone;

    if (token == tokens[index]) {
      debug writeln("Consumed ", token, " at index ", index);
      index += 1;
      return true;
    }
    return false;
  }

  string consumeIdentifier() pure @safe {
    throwIfDone;

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
    immutable line = p.top.line, row = p.top.row;
    immutable string path = p.top.path;

    p.track;
    auto expr = pExpr(p);

    if (expr !is null && p.consume(Token(';'))) {
      auto stmt = Stmt(expr);
      stmt.line = line; stmt.row = row; stmt.path = path;
      program ~= stmt;

      p.untrack;
      continue;
    }

    p.backtrack;

    p.track;
    auto def = pDef(p);

    if (def !is null) {
      auto stmt = Stmt(def);
      stmt.line = line; stmt.row = row; stmt.path = path;
      program ~= stmt;

      p.untrack;
      continue;
    }

    p.backtrack;

    throw new TokenException(
      "Invalid syntax", p.top.line, p.top.row, p.top.path);
  }

  debug writeln("Finished parsing");
  return program;
}

private static Def* pDef(Parser p) pure @safe {
  p.track;
  auto expr = pExpr(p);

  if (expr !is null) {
    string x = expr.val.match!(
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
  immutable line = p.top.line, row = p.top.row;
  immutable string path = p.top.path;

  p.track;
  auto term = pTerm(p);

  if (term !is null) {
    if (p.consume(Token('='))) {
      auto expr = pExpr(p);

      if (expr !is null) {
        p.untrack;
        return new Expr(BinOp(BinOp.Type.EQUALS, term, expr));
      }
    }
    else if (p.consume(Token('<'))) {
      auto expr = pExpr(p);

      if (expr !is null) {
        auto result = new Expr(BinOp(BinOp.Type.MEMBER, term, expr));
        result.line = line; result.row = row; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token(Token.Special.NEQUAL))) {
      auto expr = pExpr(p);

      if (expr !is null) {
        auto result = new Expr(BinOp(BinOp.Type.NEQUAL, term, expr));
        result.line = line; result.row = row; result.path = path;

        p.untrack;
        return result;
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
  immutable line = p.top.line, row = p.top.row;
  immutable string path = p.top.path;

  if (p.consume(Token('0'))) {
    auto result = new Expr(Zero());
    result.line = line; result.row = row; result.path = path;
    return result;
  }
  
  auto x = p.consumeIdentifier;
  if (x !is null) {
    auto result = new Expr(Variable(x));
    result.line = line; result.row = row; result.path = path;
    return result;
  }

  p.track;

  if (p.consume(Token('{'))) {
    auto expr = pExpr(p);
    if (expr !is null) {
      if (p.consume(Token(','))) {
        auto expr1 = pExpr(p);
        if (expr !is null && p.consume(Token('}'))) {
          auto result = new Expr(Pair(expr, expr1));
          result.line = line; result.row = row; result.path = path;

          p.untrack;
          return result;
        }
      }
      else if (p.consume(Token('}'))) {
        auto result = new Expr(Single(expr));
        result.line = line; result.row = row; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token('}'))) {
      auto result = new Expr(Zero());
      result.line = line; result.row = row; result.path = path;
      return result;
    }
  }

  p.backtrack;

  return null;
}

