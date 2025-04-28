module parser;

import std.array;
import std.sumtype;

import std.stdio; /+ For debugging +/

import lexer;
import syntax;

/+ Syntax:

   program -> { expr ";" | def }
   def -> identifier ":=" expr ";"
   expr -> pseudatom ("&" expr | "|" expr)? 
   pseudatom -> atom | "~" pseudatom | "(" expr ")"
              | ("all" | "exist") identifier "(" set ")" expr
   atom -> set ("=" set | "<" set | "/=" set | "sub" set)?
   set -> term ("U" set)?
   term -> "0" | identifier | "U" term | "P" term 
         | "{" (term ("," term)?)? "}" 
         | "{" identifier "<" set ":" expr "}"
         | "(" set ")"
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
    immutable line = p.top.line, col = p.top.col;
    immutable string path = p.top.path;

    p.track;
    auto expr = pExpr(p);

    if (expr !is null && p.consume(Token(';'))) {
      auto stmt = Stmt(expr);
      stmt.line = line; stmt.col = col; stmt.path = path;
      program ~= stmt;

      p.untrack;
      continue;
    }

    p.backtrack;

    p.track;
    auto def = pDef(p);

    if (def !is null) {
      auto stmt = Stmt(def);
      stmt.line = line; stmt.col = col; stmt.path = path;
      program ~= stmt;

      p.untrack;
      continue;
    }

    p.backtrack;

    throw new TokenException(
      "Invalid syntax", p.top.line, p.top.col, p.top.path);
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
  immutable line = p.top.line, col = p.top.col;
  immutable string path = p.top.path;

  p.track;
  auto pseudatom = pPseudatom(p);
  if (pseudatom !is null) {
    if (p.consume(Token('&'))) {
      auto expr = pExpr(p);
      if (expr !is null) {
        auto result = new Expr(BinOp(BinOp.Type.LAND, pseudatom, expr));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token('|'))) {
      auto expr = pExpr(p);
      if (expr !is null) {
        auto result = new Expr(BinOp(BinOp.Type.LOR, pseudatom, expr));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else {
      p.untrack;
      return pseudatom;
    }
  }

  p.backtrack;

  return null;
}

private static Expr* pPseudatom(Parser p) pure @safe {
  immutable line = p.top.line, col = p.top.col;
  immutable string path = p.top.path;

  p.track;
  auto atom = pAtom(p);

  if (atom !is null) {
    p.untrack;
    return atom;
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('~'))) {
    auto pseudatom = pPseudatom(p);
    if (pseudatom !is null) {
      auto result = new Expr(UnOp(UnOp.Type.LNOT, pseudatom));
      result.line = line; result.col = col; result.path = path;

      p.untrack;
      return result;
    }
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('('))) {
    auto expr = pExpr(p);
    if (expr !is null && p.consume(Token(')'))) {
      p.untrack;
      return expr;
    }
  }

  p.backtrack;

  return null;
}

private static Expr* pAtom(Parser p) pure @safe {
  immutable line = p.top.line, col = p.top.col;
  immutable string path = p.top.path;

  p.track;
  auto set = pSet(p);

  if (set !is null) {
    if (p.consume(Token('='))) {
      auto set1 = pSet(p);

      if (set1 !is null) {
        p.untrack;
        return new Expr(BinOp(BinOp.Type.EQUALS, set, set1));
      }
    }
    else if (p.consume(Token('<'))) {
      auto set1 = pSet(p);

      if (set1 !is null) {
        auto result = new Expr(BinOp(BinOp.Type.MEMBER, set, set1));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token(Token.Special.NEQUAL))) {
      auto set1 = pSet(p);

      if (set1 !is null) {
        auto result = new Expr(BinOp(BinOp.Type.NEQUAL, set, set1));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token(Token.Special.SUBSET))) {
      auto set1 = pSet(p);

      if (set1 !is null) {
        auto result = new Expr(BinOp(BinOp.Type.SUBSET, set, set1));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else {
      p.untrack;
      return set;
    }
  }

  p.backtrack;

  p.track;
  auto top = p.top;
  if (p.consume(Token(Token.Special.FORALL)) ||
      p.consume(Token(Token.Special.EXISTS)))
  {
    auto x = p.consumeIdentifier;
    if (x !is null && p.consume(Token('('))) {
      auto dom = pSet(p);

      if (dom !is null && p.consume(Token(')'))) {
        auto expr = pExpr(p);

        if (expr !is null) {
          Expr* result;
          if (top == Token(Token.Special.FORALL)) {
            result = new Expr(ForAll(Variable(x), dom, expr));
          }
          else if (top == Token(Token.Special.EXISTS)) {
            /+  exist a(x) φ  <->  ~all a(x) ~φ  +/
            result = new Expr(
              UnOp(UnOp.Type.LNOT, new Expr(
                ForAll(Variable(x), dom, new Expr(
                  UnOp(UnOp.Type.LNOT, expr)
                ))
              ))
            );
          }
          else assert(false);

          result.line = line; result.col = col; result.path = path;
          p.untrack;
          return result;
        }
      }
    }
  }

  p.backtrack;

  return null;
}

private static Expr* pSet(Parser p) pure @safe {
  immutable line = p.top.line, col = p.top.col;
  immutable string path = p.top.path;

  p.track;
  auto term = pTerm(p);

  if (term !is null) {
    if (p.consume(Token('U'))) {
      auto set = pSet(p);
      
      if (set !is null) {
        auto result =
          new Expr(UnOp(UnOp.Type.UNION, new Expr(Pair(term, set))));
        result.line = line; result.col = col; result.path = path;

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
  immutable line = p.top.line, col = p.top.col;
  immutable string path = p.top.path;

  if (p.consume(Token('0'))) {
    auto result = new Expr(Zero());
    result.line = line; result.col = col; result.path = path;
    return result;
  }
  
  auto x = p.consumeIdentifier;
  if (x !is null) {
    auto result = new Expr(Variable(x));
    result.line = line; result.col = col; result.path = path;
    return result;
  }

  p.track;
  if (p.consume(Token('U'))) {
    auto term = pTerm(p);
    if (term !is null) {
      auto result = new Expr(UnOp(UnOp.Type.UNION, term));
      result.line = line; result.col = col; result.path = path;

      p.untrack;
      return result;
    }
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('P'))) {
    auto term = pTerm(p);
    if (term !is null) {
      auto result = new Expr(UnOp(UnOp.Type.POWERSET, term));
      result.line = line; result.col = col; result.path = path;

      p.untrack;
      return result;
    }
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('{'))) {
    auto term = pTerm(p);
    if (term !is null) {
      if (p.consume(Token(','))) {
        auto term1 = pTerm(p);
        if (term1 !is null && p.consume(Token('}'))) {
          auto result = new Expr(Pair(term, term1));
          result.line = line; result.col = col; result.path = path;

          p.untrack;
          return result;
        }
      }
      else if (p.consume(Token('}'))) {
        auto result = new Expr(Single(term));
        result.line = line; result.col = col; result.path = path;

        p.untrack;
        return result;
      }
    }
    else if (p.consume(Token('}'))) {
      auto result = new Expr(Zero());
      result.line = line; result.col = col; result.path = path;

      p.untrack;
      return result;
    }
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('{'))) {
    auto y = p.consumeIdentifier;
    if (y !is null && p.consume(Token('<'))) {
      auto set = pSet(p);
      if (set !is null && p.consume(Token(':'))) {
        auto expr = pExpr(p);
        if (expr !is null && p.consume(Token('}'))) {
          auto result = new Expr(Specific(Variable(y), set, expr));
          result.line = line; result.col = col; result.path = path;

          p.untrack;
          return result;
        }
      }
    }
  }

  p.backtrack;

  p.track;
  if (p.consume(Token('('))) {
    auto set = pSet(p);
    if (set !is null && p.consume(Token(')'))) {
      p.untrack;
      return set;
    }
  }

  p.backtrack;

  return null;
}

