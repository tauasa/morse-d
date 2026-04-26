/**
 * Test runner for morse.d and audio.d unit tests.
 *
 * Build and run with:
 *   dub test
 *
 * Or compile manually:
 *   dmd -unittest -main source/morse.d source/audio.d -of=morse_test && ./morse_test
 *   ldc2 -unittest -main source/morse.d source/audio.d -of=morse_test && ./morse_test
 */
module test_runner;

// Import modules whose `unittest` blocks we want to run.
// D's -unittest flag compiles all unittest blocks; providing a main()
// here drives the test runner.

import morse;
import audio;

void main()
{
    // unittest blocks in morse.d and audio.d are run automatically
    // by the D runtime when compiled with -unittest.
    // This main() just provides an entry point; the runtime handles
    // test discovery, execution, and reporting.
    import std.stdio : writeln;
    writeln("All unit tests passed.");
}
