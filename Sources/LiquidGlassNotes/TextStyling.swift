import AppKit

/// Builds and reads the bold/italic runs that a note stores alongside its plain
/// text. The text stays a plain String (so search, titles, and timelapse keep
/// working); StyleRun offsets describe which spans carry which traits.
enum StyledText {
    static func attributed(text: String,
                           styles: [StyleRun],
                           font: NSFont,
                           color: NSColor,
                           paragraph: NSParagraphStyle?) -> NSAttributedString {
        var base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let paragraph { base[.paragraphStyle] = paragraph }

        let result = NSMutableAttributedString(string: text, attributes: base)
        let length = (text as NSString).length
        let fm = NSFontManager.shared
        for run in styles {
            guard run.start >= 0, run.length > 0, run.start + run.length <= length else { continue }
            var styled = font
            if run.bold { styled = fm.convert(styled, toHaveTrait: .boldFontMask) }
            if run.italic { styled = fm.convert(styled, toHaveTrait: .italicFontMask) }
            result.addAttribute(.font, value: styled, range: NSRange(location: run.start, length: run.length))
        }
        return result
    }

    static func extract(from storage: NSTextStorage) -> [StyleRun] {
        var runs: [StyleRun] = []
        let fm = NSFontManager.shared
        storage.enumerateAttribute(.font, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let traits = fm.traits(of: font)
            let bold = traits.contains(.boldFontMask)
            let italic = traits.contains(.italicFontMask)
            if bold || italic {
                runs.append(StyleRun(start: range.location, length: range.length, bold: bold, italic: italic))
            }
        }
        return runs
    }
}

/// An NSTextView that toggles bold/italic on ⌘B/⌘I by adding font traits to the
/// selection (or to the typing attributes when nothing is selected).
class FormattableTextView: NSTextView {

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let chars = event.charactersIgnoringModifiers?.lowercased() {
            if chars == "b" { toggleTrait(.boldFontMask); return true }
            if chars == "i" { toggleTrait(.italicFontMask); return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    // Paste as plain text so a copy from the web can't drag in foreign fonts or
    // colors; pasted text takes on the note's own style.
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    private func toggleTrait(_ trait: NSFontTraitMask) {
        let fm = NSFontManager.shared
        let range = selectedRange()

        if range.length == 0 {
            let current = (typingAttributes[.font] as? NSFont) ?? BlockView.blockFont
            let has = fm.traits(of: current).contains(trait)
            typingAttributes[.font] = has
                ? fm.convert(current, toNotHaveTrait: trait)
                : fm.convert(current, toHaveTrait: trait)
            return
        }

        guard let storage = textStorage,
              shouldChangeText(in: range, replacementString: nil) else { return }

        // Toggle off only if the whole selection already has the trait.
        var allHave = true
        storage.enumerateAttribute(.font, in: range) { value, _, _ in
            let font = (value as? NSFont) ?? BlockView.blockFont
            if !fm.traits(of: font).contains(trait) { allHave = false }
        }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            let font = (value as? NSFont) ?? BlockView.blockFont
            let updated = allHave
                ? fm.convert(font, toNotHaveTrait: trait)
                : fm.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: updated, range: sub)
        }
        storage.endEditing()
        didChangeText()
    }
}
