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
    ASSIGN
  }

  struct Identifier {
    string name;
    this(string s) pure nothrow @safe { name = s; }
  }

  alias TokenVal = SumType!(char, Special, Identifier);
  TokenVal val;

  this(char c) pure nothrow @safe { val = c; }
  this(Special x) pure nothrow @safe { val = x; }
  this(Identifier x) pure nothrow @safe { val = x; }

  bool isInvalid() pure nothrow @safe const {
    return val.match!(
      (Special x) => x == Special.INVALID,
      _ => false
    );
  }
}

class LexerOutput {
  immutable(Token)[] tokens;
  string unread;
  size_t lines;
  size_t rows;

  void merge(const LexerOutput that) pure nothrow @safe {
    tokens ~= that.tokens;
    unread = that.unread;
    lines += that.lines;
    rows = that.lines == 0 ? rows + that.rows : that.rows;
  }
}

immutable(Token)[] tokenizeFileAt(const string path) {
  LexerOutput output;

  try {
    output = tokenize(readText(path));
  }
  catch (Exception e) {
    throw new Exception("Error reading file at path '" ~ path ~ "'");
  }

  if (output.unread.length > 0) {
    throw new Exception("Invalid token in file at path '" ~ path ~ 
      "' on line " ~ to!string(output.lines) ~ ":" ~ to!string(output.rows));
  }
  
  return output.tokens;
}

private static Token nextToken(const string buff) pure nothrow @safe {
  if (buff == "=")
    return Token('=');
  if (buff == "0")
    return Token('0');
  if (buff == ";")
    return Token(';');
  if (buff == ":=")
    return Token(Token.Special.ASSIGN);

  return Token(Token.Special.INVALID);
}

private static LexerOutput tokenize(const string input) pure nothrow @safe {
  auto output = new LexerOutput;
  size_t unreadIndex;
  string buff;

  foreach (i, c; input) {
    auto lines = output.lines;
    auto rows = output.rows;

    bool breakIdentifier;

    if (c == ' ' || c == '\t') {
      breakIdentifier = true;
    }
    else if (c == '\n') {
      output.lines += 1;
      output.rows = 0;
      breakIdentifier = true;
    }
    else {
      buff ~= c;
    }

    output.rows += 1;

    if (buff.length > 0) {
      auto token = nextToken(buff);

      debug {
        if (!token.isInvalid || breakIdentifier) writeln(buff);
      }

      if (token.isInvalid && breakIdentifier)
        output.tokens ~= Token(Token.Identifier(buff));
      else if (!token.isInvalid)
        output.tokens ~= token;

      if (!token.isInvalid || breakIdentifier) {
        buff = "";
        unreadIndex = i + 1;
      }
    }
    else {
      unreadIndex = i + 1;
    }
  }

  output.unread = input[unreadIndex..$];

  return output;
}

