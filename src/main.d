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
  catch (TokenException e) {
    e.path is null
      ? stderr.writeln("Error on line ", e.line, ":", e.row, " :-- ", e.msg)
      : stderr.writeln(
          "Error at path '", e.path, "' on line ", e.line, ":", e.row,
          " :-- ", e.msg);
  }
  catch (EOFException e) {
    e.path is null
      ? stderr.writeln(e.msg)
      : stderr.writeln("Error at path '", e.path, "' :-- ", e.msg);
  }
  catch (SemanticException e) {
    stderr.writeln("Error: ", e.msg);
  }

  return 0;
}

