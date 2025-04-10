import std.stdio;

import lexer;
import parser;
import interpreter;

static enum USAGE_STR =
"Usage:
  Interpret file: lichen <file>";

int main(string[] args) {
  if (args.length <= 1) {
    writeln(USAGE_STR);
    return 0;
  }

  try {
    tokenizeFileAt(args[1]).parse.interpret;
  }
  catch (SyntaxException e) {
    stderr.writeln("Error: Syntax error");
  }
  catch (EOFException e) {
    stderr.writeln("Error: Unexpected end of file");
  }
  catch (SemanticException e) {
    stderr.writeln("Error: ", e.msg);
  }

  return 0;
}

