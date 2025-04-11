module lexer;

import std.conv;
import std.exception;
import std.file;
import std.stdio;
import std.sumtype;
import std.typecons;

struct Token {
  enum Special {
    INVALID,
    DEFINE,
    NEQUAL
  }

  alias TokenVal = SumType!(char, Special, string);
  immutable TokenVal val;
  size_t line, row;
  string path;

  this(const char c) pure nothrow @safe { val = c; }
  this(const Special x) pure nothrow @safe { val = x; }
  this(const string x) pure nothrow @safe { val = x; }

  bool isInvalid() pure nothrow @safe const {
    return val.match!(
      (Special x) => x == Special.INVALID,
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
      (immutable char c) => [ c ],
      (Special x) {
        switch (x) {
          case Special.INVALID: return "[INVALID]";
          case Special.DEFINE: return ":=";
          case Special.NEQUAL: return "/=";
          default: assert(false);
        }
      },
      (string x) => "IDENTIFIER " ~ x
    );
  }
}

class TokenException : Exception {
  size_t line, row;
  string path;
  this(string s, size_t line, size_t row, string path = null)
    pure nothrow @safe
  {
    super(s); this.line = line; this.row = row; this.path = path;
  }
}

class LexerOutput {
  immutable(Token)[] tokens;
  string unread;
  size_t lines = 1;
  size_t rows;

  void merge(const LexerOutput that) pure nothrow @safe {
    tokens ~= that.tokens;
    unread = that.unread;
    lines += that.lines;
    rows = that.lines == 0 ? rows + that.rows : that.rows;
  }
}

static immutable(Token)[] tokenizeFileAt(const string path) {
  LexerOutput output;

  try {
    output = tokenize(readText(path), path);
  }
  catch (Exception e) {
    throw new Exception("Error reading file at path '" ~ path ~ "'");
  }

  if (output.unread.length > 0) {
    throw new Exception("Invalid token in file at path '" ~ path ~ 
      "' on line " ~ to!string(output.lines) ~ ":" ~ to!string(output.rows));
  }
  
  debug output.tokens.writeln;
  return output.tokens;
}

private static Token nextToken(const string buff) pure nothrow @safe {
  if (buff == "=")  return Token('=');
  if (buff == "<")  return Token('<');
  if (buff == "0")  return Token('0');
  if (buff == ";")  return Token(';');
  if (buff == ",")  return Token(',');
  if (buff == "{")  return Token('{');
  if (buff == "}")  return Token('}');
  if (buff == ":=") return Token(Token.Special.DEFINE);
  if (buff == "/=") return Token(Token.Special.NEQUAL);
  return Token(Token.Special.INVALID);
}

private static bool isPunctuation(const char c) pure nothrow @safe {
  switch (c) {
    case '=', '<', '0', ';', ':', ',', '{', '}', '/':
      return true;
    default:
      return false;
  }
}

private static LexerOutput tokenize(
    const string input,
    const string path = null
  )
  pure nothrow @safe
{
  auto output = new LexerOutput;
  size_t unreadIndex;
  string buff;

  foreach (i, c; input) {
    bool whitespace;

    size_t line = output.lines, row = output.rows;

    if (c == ' ' || c == '\t') {
      whitespace = true;
    }
    else if (c == '\n') {
      output.lines += 1;
      output.rows = 0;
      whitespace = true;
    }
    else {
      buff ~= c;
    }

    output.rows += 1;

    bool repeat;
    do {
      repeat = false;

      if (buff.length > 0) {
        auto token = nextToken(buff);
        token.line = line;
        token.row = row;
        token.path = path;

        if (token.isInvalid) {
          size_t j;
          for (j = 0; j < buff.length; ++j) {
            if (buff[j].isPunctuation) break;
          }
          if (whitespace || (0 < j && j < buff.length)) {
            auto token1 = Token(buff[0..j]);
            token1.line = line;
            token1.row = row;
            token1.path = path;

            output.tokens ~= token1;
            buff = buff[j..$];
            unreadIndex = i - buff.length + 1;
          }
        }
        else {
          output.tokens ~= token;
          buff = "";
          unreadIndex = i + 1;
        }
      }
      else {
        unreadIndex = i + 1;
      }
    }
    while (repeat);
  }

  output.unread = input[unreadIndex..$];

  return output;
}

