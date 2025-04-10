module parser;

import std.array;
import std.typecons;

import lexer;
import syntax;

private class Parser {
  private immutable(Token)[] tokens;
  private size_t index;
  private size_t[] tracks;

  this(immutable(Token)[] ts) pure nothrow @safe { tokens = ts; }

  bool done() pure nothrow @safe const {
    return index >= tokens.length;
  }

  Token top() pure nothrow @safe const
    in (!done)
  {
    return tokens[index];
  }

  bool consume(Token token) pure nothrow @safe
    in (!done)
  {
    if (token == tokens[index]) {
      index += 1;
      return true;
    }
    return false;
  }

  void track() pure nothrow @safe {
    tracks ~= index;
  }

  void backtrack() pure nothrow @safe
    in (tracks.length > 0)
  {
    index = tracks.back;
    tracks.popBack;
  }

  void retrack() pure nothrow @safe
    in (tracks.length > 0)
  {
    index = tracks.back;
  }
}

Program parse(immutable(Token)[] tokens) pure @safe {
  auto p = new Parser(tokens);

  Program program;

  while (!p.done) {
    p.track;
    auto expr = parseExpr(p);

    if (!expr.isNull && p.consume(Token(';'))) {
      program ~= Stmt(expr.get);
      continue;
    }

    p.retrack;
    auto def = parseDef(p);

    if (!def.isNull) {
      program ~= Stmt(def.get);
      continue;
    }

    p.backtrack;
    throw new Exception("Syntax error: found '" ~ p.top.toString ~ 
      "' where statement expected");
  }

  return program;
}

Nullable!Expr parseExpr(Parser p) pure nothrow @safe {
  return Nullable!Expr.init;
}

Nullable!Def parseDef(Parser p) pure nothrow @safe {
  return Nullable!Def.init;
}

