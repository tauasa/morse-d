/**
 * Audio playback of Morse code as 700 Hz sine-wave tones.
 *
 * Generates a WAV file entirely in memory using D's standard library,
 * then pipes it to a system audio player (ffplay / aplay / afplay /
 * paplay on Unix; PowerShell Media.SoundPlayer on Windows).
 *
 * Timing (standard ~20 WPM):
 *   dot              =  60 ms
 *   dash             = 180 ms  (3 × dot)
 *   intra-char gap   =  60 ms  (between dots/dashes in one letter)
 *   inter-letter gap = 180 ms  (between letters)
 *   inter-word gap   = 420 ms  (7 × dot; triggered by " / ")
 *
 * A 10 ms linear ramp-up/down envelope is applied to each tone to
 * eliminate audible clicks at symbol boundaries.
 *
 * Authors: Tauasa Timoteo
 */
module audio;

import std.math    : sin, PI;
import std.array   : appender;
import std.string  : strip, split, empty;
import std.algorithm : filter;
import std.process : pipeProcess, Redirect, wait, ProcessException,
                     executeShell;
import std.stdio   : stderr;
import std.array   : join;

// ── Timing constants ──────────────────────────────────────────────────────────

private enum uint   SAMPLE_RATE   = 44_100;
private enum double FREQUENCY     = 700.0;
private enum double AMPLITUDE     = 0.45;
private enum uint   DOT_MS        = 60;
private enum uint   DASH_MS       = DOT_MS * 3;
private enum uint   SYMBOL_GAP_MS = DOT_MS;
private enum uint   LETTER_GAP_MS = DOT_MS * 3;
private enum uint   WORD_GAP_MS   = DOT_MS * 7;
private enum uint   RAMP_MS       = 10;

// ── WAV generation ────────────────────────────────────────────────────────────

private uint msToSamples(uint ms)
{
    return SAMPLE_RATE * ms / 1000;
}

/// Build raw 16-bit signed little-endian PCM for a sine-wave tone
/// with linear ramp-up/down envelope to prevent clicks.
private ubyte[] toneBytes(uint durationMs)
{
    uint n    = msToSamples(durationMs);
    uint ramp = msToSamples(RAMP_MS);
    auto buf  = appender!(ubyte[])();
    buf.reserve(n * 2);

    foreach (uint i; 0 .. n)
    {
        double env;
        if      (i < ramp)         env = cast(double)i / ramp;
        else if (i > n - ramp)     env = cast(double)(n - i) / ramp;
        else                       env = 1.0;

        double v = AMPLITUDE * env * sin(2.0 * PI * FREQUENCY * i / SAMPLE_RATE);
        short  s = cast(short)(v * short.max);

        buf ~= cast(ubyte)(s & 0xFF);
        buf ~= cast(ubyte)((s >> 8) & 0xFF);
    }
    return buf[];
}

/// Build zero-filled silence bytes.
private ubyte[] silenceBytes(uint durationMs)
{
    return new ubyte[](msToSamples(durationMs) * 2);
}

/// Write a 32-bit unsigned integer as 4 little-endian bytes.
private void writeU32LE(ref ubyte[] buf, uint v)
{
    buf ~= cast(ubyte)( v        & 0xFF);
    buf ~= cast(ubyte)((v >>  8) & 0xFF);
    buf ~= cast(ubyte)((v >> 16) & 0xFF);
    buf ~= cast(ubyte)((v >> 24) & 0xFF);
}

/// Write a 16-bit unsigned integer as 2 little-endian bytes.
private void writeU16LE(ref ubyte[] buf, ushort v)
{
    buf ~= cast(ubyte)( v       & 0xFF);
    buf ~= cast(ubyte)((v >> 8) & 0xFF);
}

/// Build a complete RIFF/WAV file for the given Morse string.
ubyte[] buildWav(string morse)
{
    // Pre-compute tone and silence buffers (reused for each symbol).
    ubyte[] dotBuf  = toneBytes(DOT_MS);
    ubyte[] dashBuf = toneBytes(DASH_MS);
    ubyte[] symSil  = silenceBytes(SYMBOL_GAP_MS);
    ubyte[] letSil  = silenceBytes(LETTER_GAP_MS);
    ubyte[] wrdSil  = silenceBytes(WORD_GAP_MS);

    auto pcm = appender!(ubyte[])();

    string[] words = morse.split(" / ");
    foreach (wi, word; words)
    {
        if (wi > 0) pcm ~= wrdSil;

        string[] letters = word.strip.split(" ")
                               .filter!(c => !c.empty).array;
        foreach (li, code; letters)
        {
            if (li > 0) pcm ~= letSil;
            foreach (si, sym; code)
            {
                if (si > 0) pcm ~= symSil;
                if      (sym == '.') pcm ~= dotBuf;
                else if (sym == '-') pcm ~= dashBuf;
            }
        }
    }

    ubyte[] pcmData = pcm[];
    uint    dataLen = cast(uint)pcmData.length;
    uint    byteRate = SAMPLE_RATE * 2;      // mono 16-bit

    // RIFF/WAV header (44 bytes)
    ubyte[] hdr;
    hdr ~= cast(ubyte[])"RIFF";
    writeU32LE(hdr, 36 + dataLen);           // chunk size
    hdr ~= cast(ubyte[])"WAVE";
    hdr ~= cast(ubyte[])"fmt ";
    writeU32LE(hdr, 16);                     // PCM subchunk size
    writeU16LE(hdr, 1);                      // PCM format
    writeU16LE(hdr, 1);                      // mono
    writeU32LE(hdr, SAMPLE_RATE);
    writeU32LE(hdr, byteRate);
    writeU16LE(hdr, 2);                      // block align
    writeU16LE(hdr, 16);                     // bits per sample
    hdr ~= cast(ubyte[])"data";
    writeU32LE(hdr, dataLen);

    return hdr ~ pcmData;
}

// ── Player detection & playback ───────────────────────────────────────────────

private bool commandExists(string cmd)
{
    import std.process : executeShell;
    auto result = executeShell("which " ~ cmd ~ " 2>/dev/null");
    return result.status == 0 && result.output.strip.length > 0;
}

private string[] findPlayer()
{
    version (Windows)
    {
        return null; // handled separately
    }
    else version (OSX)
    {
        if (commandExists("ffplay"))
            return ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-"];
        if (commandExists("afplay"))
            return ["afplay", "-"];
    }
    else // Linux / other Unix
    {
        if (commandExists("ffplay"))
            return ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-"];
        if (commandExists("aplay"))
            return ["aplay", "-q", "-"];
        if (commandExists("paplay"))
            return ["paplay", "--raw", "--rate=44100",
                    "--channels=1", "--format=s16le"];
        if (commandExists("sox"))
            return ["sox", "-t", "wav", "-", "-d"];
    }
    return null;
}

/**
 * Play `morse` as audio tones, blocking until playback is complete.
 *
 * Generates a WAV in memory and pipes it to the best available
 * system player. Prints a warning to stderr if no player is found.
 *
 * Params:
 *   morse = Morse code string to play.
 */
void play(string morse)
{
    ubyte[] wav = buildWav(morse);

    version (Windows)
    {
        import std.file   : tempDir, buildPath, remove;
        import std.format : format;

        string tmp = buildPath(tempDir(), "morse_audio.wav");
        import std.file : write;
        std.file.write(tmp, wav);
        scope(exit) std.file.remove(tmp);

        executeShell(
            `powershell -NoProfile -Command ` ~
            `"(New-Object Media.SoundPlayer '` ~ tmp ~ `').PlaySync()"`
        );
        return;
    }

    string[] cmd = findPlayer();
    if (cmd is null)
    {
        stderr.writeln("⚠  No audio player found. " ~
                       "Install ffmpeg (ffplay) for audio support.");
        return;
    }

    try
    {
        auto pipes = pipeProcess(cmd, Redirect.stdin);
        pipes.stdin.rawWrite(wav);
        pipes.stdin.close();
        wait(pipes.pid);
    }
    catch (ProcessException e)
    {
        stderr.writeln("⚠  Audio error: ", e.msg);
    }
}

// ── Unit tests ────────────────────────────────────────────────────────────────

unittest
{
    // WAV structure sanity checks
    ubyte[] wav = buildWav("... --- ...");

    // Must be at least header (44 bytes) + some PCM
    assert(wav.length > 44);

    // Check RIFF magic
    assert(wav[0 .. 4] == cast(ubyte[])"RIFF");
    // Check WAVE magic
    assert(wav[8 .. 12] == cast(ubyte[])"WAVE");
    // Check fmt  chunk ID
    assert(wav[12 .. 16] == cast(ubyte[])"fmt ");
    // Check data chunk ID
    assert(wav[36 .. 40] == cast(ubyte[])"data");

    // A longer Morse string should produce more PCM data
    ubyte[] short_ = buildWav(".");
    ubyte[] long_  = buildWav("... --- ...");
    assert(long_.length > short_.length);

    // Silence bytes should all be zero
    ubyte[] sil = silenceBytes(10);
    foreach (b; sil) assert(b == 0);
}
