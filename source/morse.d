/**
 * Morse code encode / decode logic.
 *
 * Format:
 *   '.'   – dot
 *   '-'   – dash
 *   ' '   – letter separator  (single space)
 *   ' / ' – word separator    (space-slash-space)
 *
 * Authors: Tauasa Timoteo
 */
module morse;

import std.string  : toUpper, strip, split, join, format, empty;
import std.array   : array, appender;
import std.algorithm : map, filter, splitter, joiner;
import std.conv    : text;
import std.exception : enforce;

// ── Lookup table ──────────────────────────────────────────────────────────────

private immutable string[2][] TABLE = [
    // Letters
    ["A", ".-"],   ["B", "-..."], ["C", "-.-."], ["D", "-.."],
    ["E", "."],    ["F", "..-."], ["G", "--."],  ["H", "...."],
    ["I", ".."],   ["J", ".---"], ["K", "-.-"],  ["L", ".-.."],
    ["M", "--"],   ["N", "-."],   ["O", "---"],  ["P", ".--."],
    ["Q", "--.-"], ["R", ".-."],  ["S", "..."],  ["T", "-"],
    ["U", "..-"],  ["V", "...-"], ["W", ".--"],  ["X", "-..-"],
    ["Y", "-.--"], ["Z", "--.."],
    // Digits
    ["0", "-----"], ["1", ".----"], ["2", "..---"], ["3", "...--"],
    ["4", "....-"], ["5", "....."], ["6", "-...."], ["7", "--..."],
    ["8", "---.."  ], ["9", "----."],
    // Punctuation
    [".", ".-.-.-"], [",", "--..--"], ["?", "..--.."],
    ["!", "-.-.--"], ["-", "-....-"], ["/", "-..-."],
    ["@", ".--.-."  ], ["(", "-.--."  ], [")", "-.--.-"],
];

// Associative arrays built once at module load (D's static constructors).
private string[dchar] encodeMap;
private dchar[string] decodeMap;

static this()
{
    foreach (entry; TABLE)
    {
        dchar ch   = entry[0][0];
        string code = entry[1];
        encodeMap[ch]   = code;
        decodeMap[code] = ch;
    }
}

// ── Encode ────────────────────────────────────────────────────────────────────

/**
 * Encode plain text → Morse code.
 *
 * Letters are separated by a single space; words by " / ".
 * Input is folded to uppercase before encoding.
 *
 * Params:
 *   text = Input string. Case-insensitive.
 *
 * Returns:
 *   Morse code string.
 *
 * Throws:
 *   Exception if text is blank or contains an unsupported character.
 */
string encode(string text)
{
    import std.uni : toUpper;

    if (text.strip.empty)
        throw new Exception("Input text is empty.");

    auto wordsOut = appender!(string[])();

    foreach (word; text.strip.split!( c => c == ' ' || c == '\t' )
                        .filter!(w => !w.empty))
    {
        auto codes = appender!(string[])();
        foreach (dchar ch; word)
        {
            dchar upper = ch.toUpper;
            auto p = upper in encodeMap;
            if (p is null)
                throw new Exception(
                    format("Unsupported character: '%s'", ch));
            codes ~= *p;
        }
        wordsOut ~= codes[].join(" ");
    }

    return wordsOut[].join(" / ");
}

// ── Decode ────────────────────────────────────────────────────────────────────

/**
 * Decode Morse code → plain text.
 *
 * Expects letters separated by single spaces and words by " / ".
 * Extra whitespace is normalised automatically.
 *
 * Params:
 *   morse = Morse code string.
 *
 * Returns:
 *   Decoded plain text (all uppercase).
 *
 * Throws:
 *   Exception if input is blank or contains an unknown sequence.
 */
string decode(string morse)
{
    if (morse.strip.empty)
        throw new Exception("Morse input is empty.");

    // Normalise: collapse runs of spaces so the split is robust.
    import std.regex : replaceAll, regex;
    string normalised = morse.strip.replaceAll(regex(r"\s+"), " ");

    auto wordsOut = appender!(string[])();

    foreach (wordChunk; normalised.split(" / "))
    {
        auto chars = appender!(dchar[])();
        foreach (code; wordChunk.strip.split(" ").filter!(c => !c.empty))
        {
            auto p = code in decodeMap;
            if (p is null)
                throw new Exception(
                    format("Unknown Morse sequence: '%s'", code));
            chars ~= *p;
        }
        wordsOut ~= chars[].map!(c => cast(string)[cast(char)c]).join;
    }

    return wordsOut[].join(" ");
}

// ── Unit tests ────────────────────────────────────────────────────────────────

unittest
{
    import std.exception : assertThrown;

    // Encoding
    assert(encode("A")        == ".-");
    assert(encode("SOS")      == "... --- ...");
    assert(encode("HI THERE") == ".... .. / - .... . .-. .");
    assert(encode("a")        == ".-");           // case-insensitive
    assert(encode("sos")      == encode("SOS"));
    assert(encode("123")      == ".---- ..--- ...--");
    assert(encode(".")        == ".-.-.-");
    assertThrown(encode("Hello #World"));
    assertThrown(encode("   "));

    // Decoding
    assert(decode(".-")                         == "A");
    assert(decode("... --- ...")                == "SOS");
    assert(decode(".... .. / - .... . .-. .")  == "HI THERE");
    assert(decode(".---- ..--- ...--")           == "123");
    assertThrown(decode("..---."));
    assertThrown(decode(""));

    // Round-trips
    assert(decode(encode("HELLO WORLD"))          == "HELLO WORLD");
    assert(decode(encode("MEETING AT 3PM"))        == "MEETING AT 3PM");
    assert(decode(encode("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
                                                   == "ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    assert(decode(encode("0123456789"))            == "0123456789");
}
