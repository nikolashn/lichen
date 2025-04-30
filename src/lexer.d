module lexer;

import std.conv : to;
import std.file : readText;
//import std.stdio : writeln;
import std.sumtype;

struct Token {
  enum Special {
    NONE,
    DEFINE,
    NEQUAL,
    SUBSET,
    FORALL,
    EXISTS,
    PATTERN
  }

  alias TokenVal = SumType!(char, Special, string);
  immutable TokenVal val;
  size_t line, col;
  string path;

  this(const char c) pure nothrow @safe { val = c; }
  this(const Special x) pure nothrow @safe { val = x; }
  this(const string x) pure nothrow @safe { val = x; }

  bool isNone() pure nothrow @safe const {
    return val.match!(
      (Special x) => x == Special.NONE,
      _ => false
    );
  }

  string getIdentifier() pure nothrow @safe const {
    return val.match!(
      (string x) => x,
      _ => null
    );
  }

  bool opEquals(const Token o) pure nothrow @safe const {
    return val.match!(
      (char c) => o.val.match!(
        (char d) => c == d,
        _ => false
      ),
      (Special x) => o.val.match!(
        (Special y) => x == y,
        _ => false
      ),
      (string x) => o.val.match!(
        (string y) => x == y,
        _ => false
      )
    );
  }

  string toString() pure nothrow @safe const {
    return val.match!(
      (immutable char c) => [ '"', c, '"' ],
      (Special x) {
        switch (x) {
          case Special.NONE: return "[NONE]";
          case Special.DEFINE: return ":=";
          case Special.NEQUAL: return "/=";
          case Special.SUBSET: return "sub";
          case Special.FORALL: return "all";
          case Special.EXISTS: return "exist";
          case Special.PATTERN: return "pattern";
          default: assert(false);
        }
      },
      (string x) => "IDENTIFIER " ~ x
    );
  }
}

class TokenException : Exception {
  size_t line, col;
  string path;
  this(string s, size_t line, size_t col, string path = null)
    pure nothrow @safe
  {
    super(s); this.line = line; this.col = col; this.path = path;
  }
}

struct Lexer {
  immutable(Token)[] tokens;
  size_t lines = 1, cols = 1;
  size_t current;
  const string input, path;

  this(const string s, const string p = null) pure nothrow @safe {
    input = s; path = p;
  }

  void tokenize() pure nothrow @safe {
    while (!done) {
      auto line = lines, col = cols, p = path;
      auto c = input[current];

      auto t = getToken;
      t.line = line; t.col = col; t.path = p;

      if (!t.isNone)
        add(t);

      if (c == '\n') {
        lines += 1;
        cols = 1;
      }
    }
  }

  private void add(const Token t) pure nothrow @safe { tokens ~= t; }

  private bool done() pure nothrow @safe const {
    return current >= input.length;
  }

  private char next() pure nothrow @safe {
    auto c = input[current];
    current += 1;
    cols += 1;
    return c;
  }

  private bool match(const char c) pure nothrow @safe {
    if (done) return false;
    if (input[current] != c) return false;
    current += 1;
    cols += 1;
    return true;
  }

  private static bool canIdentifier(const char c) pure nothrow @safe {
    switch (c) {
      case ':', '/', '=', '<', '$', ';', ',', '{', '}', '~', '|', '&', '(', ')',
           '\n', ' ', '\t':
      {
        return false;
      }
      default:
        return true;
    }
  }

  private Token getToken() pure nothrow @safe {
    if (done)
      return Token(Token.Special.NONE);

    auto c = next;
    switch (c) {
      case ':':
        return match('=') ? Token(Token.Special.DEFINE) : Token(':');

      case '/':
        if (match('=')) {
          return Token(Token.Special.NEQUAL);
        }
        else if (match('+')) {
          size_t depth = 1;
          while (!done && depth > 0) {
            if (match('/') && match('+'))
              depth += 1;
            else if (match('+') && match('/'))
              depth -= 1;
            else
              next;
          }
          return getToken;
        }
        else {
          return Token('/');
        }

      case '=', '<', '0', ';', ',', '{', '}', '~', '|', '&', '(', ')':
        return Token(c);

      case '\n', ' ', '\t':
        return Token(Token.Special.NONE);

      default:
        assert(canIdentifier(c));

        string name;
        name ~= c;

        while (!done && canIdentifier(input[current])) {
          name ~= next;
        }

        if (name == "U")
          return Token('U');

        if (name == "P")
          return Token('P');

        if (name == "sub")
          return Token(Token.Special.SUBSET);

        if (name == "all")
          return Token(Token.Special.FORALL);

        if (name == "exist")
          return Token(Token.Special.EXISTS);

        if (name == "pattern")
          return Token(Token.Special.PATTERN);

        return Token(name);
    }
  }
}

static immutable(Token)[] tokenizeFileAt(const string path) {
  Lexer lexer = Lexer(readText(path), path);

  try {
    lexer.tokenize;
  }
  catch (Exception e) {
    throw new Exception("Could not read file at path '" ~ path ~ "'");
  }
  
  //debug lexer.tokens.writeln;
  return lexer.tokens;
}

