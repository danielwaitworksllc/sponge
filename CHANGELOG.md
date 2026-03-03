# Changelog

## 2026-03-03
Added Gemini audio transcription pipeline: after recording stops, the M4A file is uploaded to Gemini 2.5 Flash via the Files API to produce a high-quality transcript with punctuation, capitalization, and speaker labels (~$0.07/hr). Also improved SpeechAnalyzerService to use `bestAvailableAudioFormat` for dynamic format negotiation instead of hardcoded 16kHz PCM, reducing format-mismatch crashes. Reset TCC permissions to fix the app crash on Record tap.

## 2026-03-02
Added XCUITest target with 7 UI tests covering app launch, main window, settings, recording detail tabs, and the Regenerate AI Notes button. Added autonomous development workflow to CLAUDE.md so builds, code reviews, and tests run automatically after every change.

## 2026-03-02
Added "Regenerate AI Notes" button to the recording detail view, allowing students to retry AI note generation for recordings where it failed (e.g. closed laptop, bad API key). Fixed live UI updates after regeneration by switching SDRecording bindings to `@Bindable` in detail, summary, and recall views.

## 2026-03-02
Updated CLAUDE.md to reflect macOS 26 deployment target and SpeechAnalyzer API details. Removed `@available(macOS 26.0, *)` annotation from SpeechAnalyzerService (redundant given min target). Deleted stale CHANGELOG.md and convert-docs.py scripts.
