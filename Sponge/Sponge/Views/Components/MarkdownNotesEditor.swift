//
//  MarkdownNotesEditor.swift
//  Sponge
//
//  A rich text editor for markdown notes with live rendering, formatting toolbar, and keyboard shortcuts.
//

import SwiftUI
import AppKit

struct MarkdownNotesEditor: View {
    @Binding var text: String
    @Binding var noteTitle: String
    @State private var editorHeight: CGFloat = 220
    @State private var isDragging: Bool = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEditorFocused: Bool

    private let minHeight: CGFloat = 150
    private let maxHeight: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            formattingToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.03))
            Divider()
            LiveMarkdownEditor(text: $text)
                .frame(height: editorHeight)
            resizeHandle
        }
        .background(Color.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            TextField("Note Title (optional)", text: $noteTitle)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .focused($isTitleFocused)
            Spacer()
            Text("\(wordCount) words")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
    }

    private var formattingToolbar: some View {
        HStack(spacing: 4) {
            FormatButtonWithLabel(label: "H1", tooltip: "Heading 1") {
                insertMarkdown(prefix: "# ", suffix: "")
            }
            FormatButtonWithLabel(label: "H2", tooltip: "Heading 2") {
                insertMarkdown(prefix: "## ", suffix: "")
            }
            FormatButtonWithLabel(label: "H3", tooltip: "Heading 3") {
                insertMarkdown(prefix: "### ", suffix: "")
            }

            toolbarDivider

            FormatButton(icon: "bold", tooltip: "Bold (Cmd+B)") {
                insertMarkdown(prefix: "**", suffix: "**")
            }
            FormatButton(icon: "italic", tooltip: "Italic (Cmd+I)") {
                insertMarkdown(prefix: "_", suffix: "_")
            }
            FormatButton(icon: "strikethrough", tooltip: "Strikethrough (Cmd+Shift+X)") {
                insertMarkdown(prefix: "~~", suffix: "~~")
            }
            FormatButton(icon: "underline", tooltip: "Underline (Cmd+U)") {
                insertMarkdown(prefix: "<u>", suffix: "</u>")
            }
            FormatButton(icon: "highlighter", tooltip: "Highlight") {
                insertMarkdown(prefix: "==", suffix: "==")
            }

            toolbarDivider

            FormatButton(icon: "list.bullet", tooltip: "Bullet List") {
                insertMarkdown(prefix: "- ", suffix: "", isLinePrefix: true)
            }
            FormatButton(icon: "list.number", tooltip: "Numbered List") {
                insertMarkdown(prefix: "1. ", suffix: "", isLinePrefix: true)
            }
            FormatButton(icon: "checklist", tooltip: "Checklist") {
                insertMarkdown(prefix: "- [ ] ", suffix: "", isLinePrefix: true)
            }

            toolbarDivider

            FormatButton(icon: "increase.indent", tooltip: "Indent (Tab)") {
                NotificationCenter.default.post(name: .indentLine, object: nil, userInfo: ["direction": "indent"])
            }
            FormatButton(icon: "decrease.indent", tooltip: "Outdent (Shift+Tab)") {
                NotificationCenter.default.post(name: .indentLine, object: nil, userInfo: ["direction": "outdent"])
            }
            FormatButton(icon: "minus", tooltip: "Horizontal Rule") {
                insertMarkdown(prefix: "\n---\n", suffix: "", isLinePrefix: false)
            }
            FormatButton(icon: "text.quote", tooltip: "Block Quote") {
                insertMarkdown(prefix: "> ", suffix: "", isLinePrefix: true)
            }

            Spacer()

            Text("Cmd+B bold · Cmd+I italic")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 3)
    }

    private var resizeHandle: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.secondary.opacity(isDragging ? 0.4 : 0.2))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
            Spacer()
        }
        .frame(height: 16)
        .background(Color.secondary.opacity(0.03))
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newHeight = editorHeight + value.translation.height
                    editorHeight = min(max(newHeight, minHeight), maxHeight)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var wordCount: Int {
        text.split(separator: " ").count
    }

    private func insertMarkdown(prefix: String, suffix: String, isLinePrefix: Bool = false) {
        NotificationCenter.default.post(
            name: .insertMarkdown,
            object: nil,
            userInfo: ["prefix": prefix, "suffix": suffix, "isLinePrefix": isLinePrefix]
        )
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let insertMarkdown = Notification.Name("insertMarkdown")
    static let indentLine = Notification.Name("indentLine")
}

// MARK: - Format Button with Label

struct FormatButtonWithLabel: View {
    let label: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Format Button with Icon

struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Live Markdown Editor

// Custom NSTextView that handles keyboard shortcuts
class MarkdownTextView: NSTextView {
    var onBold: (() -> Void)?
    var onItalic: (() -> Void)?
    var onStrikethrough: (() -> Void)?
    var onUnderline: (() -> Void)?
    var onIndent: ((_ outdent: Bool) -> Void)?
    var onEnterPressed: ((String) -> String?)?

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+B (bold)
        if flags == .command && event.charactersIgnoringModifiers == "b" {
            onBold?()
            return
        }

        // Cmd+I (italic)
        if flags == .command && event.charactersIgnoringModifiers == "i" {
            onItalic?()
            return
        }

        // Cmd+U (underline)
        if flags == .command && event.charactersIgnoringModifiers == "u" {
            onUnderline?()
            return
        }

        // Cmd+Shift+X (strikethrough)
        if flags == [.command, .shift] && event.charactersIgnoringModifiers == "x" {
            onStrikethrough?()
            return
        }

        // Tab key (indent)
        if event.keyCode == 48 { // Tab
            if flags.contains(.shift) {
                onIndent?(true) // outdent
            } else {
                onIndent?(false) // indent
            }
            return
        }

        // Enter/Return key
        if event.keyCode == 36 || event.keyCode == 76 {
            if let currentLine = getCurrentLine(), let prefix = onEnterPressed?(currentLine) {
                insertText("\n\(prefix)", replacementRange: selectedRange())
                return
            }
        }

        super.keyDown(with: event)
    }

    private func getCurrentLine() -> String? {
        let text = string as NSString
        let cursorLocation = selectedRange().location

        var lineStart = cursorLocation
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = cursorLocation
        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        return text.substring(with: lineRange)
    }
}

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView()
        textView.autoresizingMask = [.width, .height]
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        textView.textContainerInset = NSSize(width: 16, height: 16)

        // Set up keyboard handlers
        let coordinator = context.coordinator
        textView.onBold = { [weak coordinator] in
            coordinator?.toggleWrap(prefix: "**", suffix: "**")
        }
        textView.onItalic = { [weak coordinator] in
            coordinator?.toggleWrap(prefix: "_", suffix: "_")
        }
        textView.onStrikethrough = { [weak coordinator] in
            coordinator?.toggleWrap(prefix: "~~", suffix: "~~")
        }
        textView.onUnderline = { [weak coordinator] in
            coordinator?.toggleWrap(prefix: "<u>", suffix: "</u>")
        }
        textView.onIndent = { [weak coordinator] outdent in
            coordinator?.indentCurrentLine(outdent: outdent)
        }
        textView.onEnterPressed = { [weak coordinator] currentLine in
            return coordinator?.getListContinuation(for: currentLine)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.applyMarkdownStyling(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let plainText = context.coordinator.getPlainText(from: textView)
        if plainText != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyMarkdownStyling(to: textView)

            if let firstRange = selectedRanges.first?.rangeValue,
               firstRange.location <= textView.string.count {
                textView.setSelectedRange(firstRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LiveMarkdownEditor
        weak var textView: NSTextView?
        private var isUpdating = false
        private var notificationObservers: [Any] = []

        init(_ parent: LiveMarkdownEditor) {
            self.parent = parent
            super.init()

            notificationObservers.append(
                NotificationCenter.default.addObserver(
                    forName: .insertMarkdown, object: nil, queue: .main
                ) { [weak self] notification in
                    self?.handleInsertMarkdown(notification)
                }
            )

            notificationObservers.append(
                NotificationCenter.default.addObserver(
                    forName: .indentLine, object: nil, queue: .main
                ) { [weak self] notification in
                    let direction = notification.userInfo?["direction"] as? String ?? "indent"
                    self?.indentCurrentLine(outdent: direction == "outdent")
                }
            )
        }

        deinit {
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func handleInsertMarkdown(_ notification: Notification) {
            guard let textView = textView,
                  let userInfo = notification.userInfo,
                  let prefix = userInfo["prefix"] as? String,
                  let suffix = userInfo["suffix"] as? String,
                  let isLinePrefix = userInfo["isLinePrefix"] as? Bool else { return }

            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            if isLinePrefix {
                var lineStart = selectedRange.location
                while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
                    lineStart -= 1
                }

                if lineStart == selectedRange.location && lineStart > 0 {
                    textView.insertText("\n\(prefix)", replacementRange: selectedRange)
                } else {
                    textView.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
                }
            } else if selectedRange.length > 0 {
                let selectedText = text.substring(with: selectedRange)
                let replacement = "\(prefix)\(selectedText)\(suffix)"
                textView.insertText(replacement, replacementRange: selectedRange)
            } else {
                textView.insertText("\(prefix)\(suffix)", replacementRange: selectedRange)
                let newLocation = selectedRange.location + prefix.count
                textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            }
        }

        // MARK: - Toggle Wrap (for keyboard shortcuts)

        func toggleWrap(prefix: String, suffix: String) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            if selectedRange.length > 0 {
                let selectedText = text.substring(with: selectedRange)
                // Check if already wrapped — if so, unwrap
                if selectedText.hasPrefix(prefix) && selectedText.hasSuffix(suffix) && selectedText.count > prefix.count + suffix.count {
                    let inner = String(selectedText.dropFirst(prefix.count).dropLast(suffix.count))
                    textView.insertText(inner, replacementRange: selectedRange)
                } else {
                    textView.insertText("\(prefix)\(selectedText)\(suffix)", replacementRange: selectedRange)
                }
            } else {
                textView.insertText("\(prefix)\(suffix)", replacementRange: selectedRange)
                textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: 0))
            }
        }

        // MARK: - Indent / Outdent

        func indentCurrentLine(outdent: Bool) {
            guard let textView = textView else { return }
            let text = textView.string as NSString
            let cursorLocation = textView.selectedRange().location

            var lineStart = cursorLocation
            while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
                lineStart -= 1
            }

            if outdent {
                // Remove leading tab or 4 spaces
                let lineText = text.substring(from: lineStart)
                if lineText.hasPrefix("\t") {
                    textView.insertText("", replacementRange: NSRange(location: lineStart, length: 1))
                } else if lineText.hasPrefix("    ") {
                    textView.insertText("", replacementRange: NSRange(location: lineStart, length: 4))
                }
            } else {
                // Insert 4 spaces at line start
                textView.insertText("    ", replacementRange: NSRange(location: lineStart, length: 0))
            }
        }

        func getListContinuation(for line: String) -> String? {
            // Preserve leading whitespace (indentation)
            let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Checkbox: - [ ] or - [x]
            if trimmedLine.hasPrefix("- [ ] ") || trimmedLine.hasPrefix("- [x] ") || trimmedLine.hasPrefix("- [X] ") {
                let content = String(trimmedLine.dropFirst(6))
                if content.isEmpty { return nil }
                return "\(leadingWhitespace)- [ ] "
            }

            // Block quote: >
            if trimmedLine.hasPrefix("> ") {
                let content = String(trimmedLine.dropFirst(2))
                if content.isEmpty { return nil }
                return "\(leadingWhitespace)> "
            }

            // Bullet points (- or *)
            if trimmedLine.hasPrefix("- ") {
                if trimmedLine == "- " || trimmedLine == "-" { return nil }
                return "\(leadingWhitespace)- "
            }
            if trimmedLine.hasPrefix("* ") {
                if trimmedLine == "* " || trimmedLine == "*" { return nil }
                return "\(leadingWhitespace)* "
            }

            // Numbered lists
            if let match = trimmedLine.range(of: "^(\\d+)\\. ", options: .regularExpression) {
                let numberStr = String(trimmedLine[trimmedLine.startIndex..<match.upperBound])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                let content = String(trimmedLine[match.upperBound...])
                if content.isEmpty { return nil }
                if let number = Int(numberStr) {
                    return "\(leadingWhitespace)\(number + 1). "
                }
            }

            return nil
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }

            isUpdating = true
            parent.text = textView.string
            applyMarkdownStyling(to: textView)
            isUpdating = false
        }

        func getPlainText(from textView: NSTextView) -> String {
            return textView.string
        }

        func applyMarkdownStyling(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string

            let baseFont = NSFont.systemFont(ofSize: 14)
            let baseColor = NSColor.labelColor
            let hiddenFont = NSFont.systemFont(ofSize: 0.1)
            let hiddenColor = NSColor.clear

            let baseParagraphStyle = NSMutableParagraphStyle()
            baseParagraphStyle.lineSpacing = 4

            textStorage.beginEditing()
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: baseParagraphStyle
            ], range: fullRange)

            let lines = text.components(separatedBy: "\n")
            var currentLocation = 0

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Horizontal rule
                if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                    let lineRange = NSRange(location: currentLocation, length: line.count)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.separatorColor, range: lineRange)
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
                }
                // Headings
                else if trimmed.hasPrefix("### ") {
                    let headerFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
                    let markerLen = line.distance(from: line.startIndex, to: line.range(of: "### ")!.upperBound)
                    if line.count > markerLen {
                        let contentRange = NSRange(location: currentLocation + markerLen, length: line.count - markerLen)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    let markerRange = NSRange(location: currentLocation, length: markerLen)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                } else if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                    let headerFont = NSFont.systemFont(ofSize: 17, weight: .semibold)
                    let markerLen = line.distance(from: line.startIndex, to: line.range(of: "## ")!.upperBound)
                    if line.count > markerLen {
                        let contentRange = NSRange(location: currentLocation + markerLen, length: line.count - markerLen)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    let markerRange = NSRange(location: currentLocation, length: markerLen)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                } else if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                    let headerFont = NSFont.systemFont(ofSize: 20, weight: .bold)
                    let markerLen = line.distance(from: line.startIndex, to: line.range(of: "# ")!.upperBound)
                    if line.count > markerLen {
                        let contentRange = NSRange(location: currentLocation + markerLen, length: line.count - markerLen)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    let markerRange = NSRange(location: currentLocation, length: markerLen)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
                // Block quotes
                else if trimmed.hasPrefix("> ") {
                    let lineRange = NSRange(location: currentLocation, length: line.count)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                    let quoteParagraph = NSMutableParagraphStyle()
                    quoteParagraph.lineSpacing = 4
                    quoteParagraph.headIndent = 20
                    quoteParagraph.firstLineHeadIndent = 20
                    textStorage.addAttribute(.paragraphStyle, value: quoteParagraph, range: lineRange)
                    // Dim the > marker
                    if let markerRange = line.range(of: "> ") {
                        let markerLen = line.distance(from: line.startIndex, to: markerRange.upperBound)
                        let nsMarkerRange = NSRange(location: currentLocation, length: markerLen)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: nsMarkerRange)
                    }
                }
                // Checklist items
                else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                    if let markerRange = line.range(of: "- \\[[ xX]\\] ", options: .regularExpression) {
                        let markerLen = line.distance(from: line.startIndex, to: markerRange.upperBound)
                        let nsMarkerRange = NSRange(location: currentLocation, length: markerLen)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsMarkerRange)
                        // Strikethrough completed items
                        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                            let contentRange = NSRange(location: currentLocation + markerLen, length: line.count - markerLen)
                            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                            textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
                        }
                    }
                }
                // Bullet points
                else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    if let markerRange = line.range(of: "^\\s*[\\-\\*] ", options: .regularExpression) {
                        let markerLen = line.distance(from: line.startIndex, to: markerRange.upperBound)
                        let nsMarkerRange = NSRange(location: currentLocation, length: markerLen)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsMarkerRange)
                    }
                }
                // Numbered lists
                else if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                    if let match = line.range(of: "^\\s*\\d+\\. ", options: .regularExpression) {
                        let markerLength = line.distance(from: line.startIndex, to: match.upperBound)
                        let markerRange = NSRange(location: currentLocation, length: markerLength)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: markerRange)
                    }
                }

                // Apply inline formatting
                applyInlineFormatting(to: textStorage, in: line, startingAt: currentLocation, baseFont: baseFont, hiddenFont: hiddenFont, hiddenColor: hiddenColor)

                currentLocation += line.count + 1
            }

            textStorage.endEditing()
        }

        private func hideMarker(in textStorage: NSTextStorage, range: NSRange, hiddenFont: NSFont, hiddenColor: NSColor) {
            textStorage.addAttribute(.font, value: hiddenFont, range: range)
            textStorage.addAttribute(.foregroundColor, value: hiddenColor, range: range)
        }

        private func applyInlineFormatting(to textStorage: NSTextStorage, in line: String, startingAt offset: Int, baseFont: NSFont, hiddenFont: NSFont, hiddenColor: NSColor) {
            // Bold: **text** or __text__
            if let boldRegex = try? NSRegularExpression(pattern: "(\\*\\*|__)(.+?)\\1") {
                let matches = boldRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 2)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)
                    let boldFont = NSFont.boldSystemFont(ofSize: baseFont.pointSize)
                    textStorage.addAttribute(.font, value: boldFont, range: contentNSRange)

                    let markerLength = 2
                    let startMarker = NSRange(location: offset + match.range.location, length: markerLength)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - markerLength, length: markerLength)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }

            // Italic: *text* or _text_ (not ** or __)
            if let italicRegex = try? NSRegularExpression(pattern: "(?<![\\*_])([\\*_])(?![\\*_])(.+?)(?<![\\*_])\\1(?![\\*_])") {
                let matches = italicRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 2)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)
                    let italicFont = NSFontManager.shared.font(
                        withFamily: baseFont.familyName ?? "System Font",
                        traits: .italicFontMask,
                        weight: 5,
                        size: baseFont.pointSize
                    ) ?? NSFont.systemFont(ofSize: baseFont.pointSize)
                    textStorage.addAttribute(.font, value: italicFont, range: contentNSRange)

                    let startMarker = NSRange(location: offset + match.range.location, length: 1)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - 1, length: 1)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }

            // Strikethrough: ~~text~~
            if let strikeRegex = try? NSRegularExpression(pattern: "~~(.+?)~~") {
                let matches = strikeRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 1)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentNSRange)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentNSRange)

                    let startMarker = NSRange(location: offset + match.range.location, length: 2)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - 2, length: 2)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }

            // Highlight: ==text==
            if let highlightRegex = try? NSRegularExpression(pattern: "==(.+?)==") {
                let matches = highlightRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 1)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: contentNSRange)

                    let startMarker = NSRange(location: offset + match.range.location, length: 2)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - 2, length: 2)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }

            // Underline: <u>text</u>
            if let underlineRegex = try? NSRegularExpression(pattern: "<u>(.+?)</u>") {
                let matches = underlineRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 1)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)
                    textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: contentNSRange)

                    let startMarker = NSRange(location: offset + match.range.location, length: 3) // <u>
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - 4, length: 4) // </u>
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }
        }
    }
}

#Preview {
    MarkdownNotesEditor(text: .constant("# Heading 1\n\nSome **bold** and _italic_ text.\n\n## Heading 2\n\n- Bullet point\n- Another point\n\n1. Numbered\n2. List\n\n~~strikethrough~~ and ==highlighted== text\n\n> A block quote\n\n- [ ] Todo item\n- [x] Done item"), noteTitle: .constant("My Notes"))
        .frame(width: 500)
        .padding()
}
