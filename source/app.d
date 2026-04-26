/**
 * Morse Code Converter  v2.0.0
 * CLI entry point.
 *
 * Usage:
 *   morse encode [--play] <text ...>
 *   morse decode [--play] <morse ...>
 *   morse --help
 *
 * Examples:
 *   morse encode "Hello World"
 *   morse encode --play SOS
 *   morse decode "... --- ..."
 *   morse decode --play ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
 *
 * Authors: Tauasa Timoteo
 */
module app;

import std.stdio    : writeln, writef, writefln, stderr, write;
import std.string   : join, strip, empty, leftJustify;
import std.array    : array, appender;
import std.getopt   : getopt, GetoptResult, config, defaultGetoptPrinter;
import std.algorithm : splitter, filter, map;
import std.conv     : text;
import core.stdc.stdlib : exit;

import morse : encode, decode;
import audio : play, buildWav;

// ── Help / version ────────────────────────────────────────────────────────────

private enum VERSION = "2.0.0";

private enum HELP = `
Morse Code Converter v` ~ VERSION ~ `

USAGE:
  morse encode [--play] <text ...>
  morse decode [--play] <morse ...>
  morse --help

COMMANDS:
  encode    Convert plain text to Morse code
  decode    Convert Morse code to plain text

OPTIONS:
  -p  --play    Play 700 Hz audio tones while printing output
  -h  --help    Show this help message

MORSE FORMAT:
  .       dot
  -       dash
  (space) letter separator
  /       word separator  (space-slash-space)

SUPPORTED CHARACTERS:
  A-Z  0-9  . , ? ! - / @ ( )

EXAMPLES:
  morse encode "Hello World"
  morse encode --play SOS
  morse decode "... --- ..."
  morse decode --play ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
`;

// ── Output box ────────────────────────────────────────────────────────────────

private enum WIDTH = 60;

private void printBoxTop()
{
    writeln("┌", "─".rep(WIDTH), "┐");
}

private void printBoxBottom()
{
    writeln("└", "─".rep(WIDTH), "┘");
}

private void printDivider()
{
    writeln("├", "─".rep(WIDTH), "┤");
}

/// Print a labelled row, word-wrapping long values across multiple lines.
private void printRow(string label, string value)
{
    enum inner = WIDTH - 2;                 // space inside │ borders
    writefln("│ %-*s │", inner, label ~ ":");
    foreach (line; wordWrap(value, inner))
        writefln("│ %-*s │", inner, line);
}

/// Word-wrap `text` to lines of at most `maxWidth` characters.
private string[] wordWrap(string text, size_t maxWidth)
{
    if (text.length <= maxWidth)
        return [text];

    auto lines   = appender!(string[])();
    string current = "";

    foreach (word; text.splitter(' ').filter!(w => !w.empty))
    {
        if (current.empty)
            current = word;
        else if (current.length + 1 + word.length <= maxWidth)
            current ~= " " ~ word;
        else
        {
            lines ~= current;
            current = word;
        }
    }
    if (!current.empty)
        lines ~= current;
    return lines[];
}

// ── String replicate helper ───────────────────────────────────────────────────

private string rep(string s, size_t n)
{
    import std.range : repeat;
    import std.array : join;
    return s.repeat(n).join;
}

// ── Subcommand handlers ───────────────────────────────────────────────────────

private void runEncode(string input, bool doPlay)
{
    printBoxTop();
    printRow("Input  (Text)", input);
    printDivider();

    try
    {
        string morse = encode(input);
        printRow("Output (Morse)", morse);
        printBoxBottom();
        if (doPlay)
        {
            stderr.writeln("\n♪  Playing…");
            play(morse);
            stderr.writeln("♪  Done.");
        }
    }
    catch (Exception e)
    {
        printBoxBottom();
        stderr.writeln("error: ", e.msg);
        exit(1);
    }
}

private void runDecode(string input, bool doPlay)
{
    printBoxTop();
    printRow("Input  (Morse)", input);
    printDivider();

    try
    {
        string decoded = decode(input);
        printRow("Output (Text)", decoded);
        printBoxBottom();
        if (doPlay)
        {
            stderr.writeln("\n♪  Playing…");
            play(input);
            stderr.writeln("♪  Done.");
        }
    }
    catch (Exception e)
    {
        printBoxBottom();
        stderr.writeln("error: ", e.msg);
        exit(1);
    }
}

// ── Entry point ───────────────────────────────────────────────────────────────

void main(string[] args)
{
    // Top-level --help before subcommand check
    if (args.length < 2 ||
        args[1] == "--help" || args[1] == "-h" || args[1] == "help")
    {
        write(HELP);
        return;
    }

    string command = args[1];
    if (command != "encode" && command != "decode")
    {
        stderr.writeln("error: Unknown command '", command,
                       "'. Expected 'encode' or 'decode'.");
        stderr.writeln("Run 'morse --help' for usage.");
        exit(1);
    }

    // Shift args past the subcommand for getopt
    string[] subArgs = args[0 .. 1] ~ args[2 .. $];

    bool doPlay = false;
    try
    {
        auto result = getopt(subArgs,
            config.bundling,
            "play|p", "Play 700 Hz audio tones while printing output", &doPlay,
        );
        if (result.helpWanted)
        {
            write(HELP);
            return;
        }
    }
    catch (Exception e)
    {
        stderr.writeln("error: ", e.msg);
        exit(1);
    }

    // Remaining positional args after getopt
    string[] positional = subArgs[1 .. $];   // strip argv[0]
    if (positional.empty)
    {
        stderr.writeln("error: No input provided.");
        stderr.writeln("Run 'morse --help' for usage.");
        exit(1);
    }

    string input = positional.join(" ");

    if (command == "encode")
        runEncode(input, doPlay);
    else
        runDecode(input, doPlay);
}
