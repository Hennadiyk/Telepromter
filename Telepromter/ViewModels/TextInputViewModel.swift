//
//  TextInputViewModel.swift
//  Teleprompter
//
//  Created by Hennadiy Kvasov.
//

import Foundation
import PDFKit
import UniformTypeIdentifiers
import Observation

@Observable @MainActor
final class TextInputViewModel {
    var showDocumentPicker = false
    var errorMessage: String?

    func handleDocumentSelection(url: URL, contentVM: ContentViewModel) {
        defer { url.stopAccessingSecurityScopedResource() }

        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access file permissions."
            return
        }

        do {
            let fileExtension = url.pathExtension.lowercased()
            let text: String

            switch fileExtension {
            case "txt":
                text = try String(contentsOf: url, encoding: .utf8)
            case "pdf":
                guard let pdfDoc = PDFDocument(url: url) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF."])
                }
                text = extractText(from: pdfDoc)
            case "rtf":
                let attrStr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                text = attrStr.string
            case "pages":
                errorMessage = "Pages files are not directly supported. Please export to RTF or PDF."
                return
            default:
                errorMessage = "Unsupported file type. Use TXT, PDF, RTF, or export Pages."
                return
            }

            let cleaned = cleanText(text)
            if cleaned.isEmpty || !isReadable(cleaned) {
                errorMessage = "File content unreadable or empty after cleaning. Please try another file."
            } else {
                contentVM.textInput = cleaned
                errorMessage = nil
            }

        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    private func extractText(from pdf: PDFDocument) -> String {
        (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    }

    private func cleanText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "[\\p{Cc}\\p{Cf}]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let ligatures: [String: String] = [
            "ﬁ": "fi", "ﬂ": "fl", "ﬀ": "ff", "ﬃ": "ffi", "ﬄ": "ffl",
            "\u{2018}": "'", "\u{2013}": "-", "\u{2014}": "-", "\u{2026}": "...", "æ": "ae", "œ": "oe"
        ]

        ligatures.forEach { cleaned = cleaned.replacingOccurrences(of: $0.key, with: $0.value) }

        return cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func isReadable(_ text: String) -> Bool {
        let printableScalars = text.unicodeScalars.filter { $0.value >= 32 && $0.value <= 126 }
        let ratio = Double(printableScalars.count) / Double(text.unicodeScalars.count)
        return ratio > 0.8 && text.count > 10
    }
}
