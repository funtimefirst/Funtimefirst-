import Foundation

struct CodeFile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var content: String
    var language: ProgrammingLanguage
    var lastModified: Date

    init(id: UUID = UUID(), name: String, content: String = "", language: ProgrammingLanguage = .swift, lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.content = content
        self.language = language
        self.lastModified = lastModified
    }

    static func == (lhs: CodeFile, rhs: CodeFile) -> Bool {
        lhs.id == rhs.id
    }
}

enum ProgrammingLanguage: String, CaseIterable, Codable {
    case swift = "swift"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case kotlin = "kotlin"
    case java = "java"
    case cpp = "cpp"
    case c = "c"
    case go = "go"
    case rust = "rust"
    case html = "html"
    case css = "css"
    case json = "json"
    case markdown = "markdown"
    case bash = "bash"
    case other = "other"

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .kotlin: return "Kotlin"
        case .java: return "Java"
        case .cpp: return "C++"
        case .c: return "C"
        case .go: return "Go"
        case .rust: return "Rust"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .bash: return "Bash"
        case .other: return "Other"
        }
    }

    var fileExtension: String {
        switch self {
        case .swift: return "swift"
        case .python: return "py"
        case .javascript: return "js"
        case .typescript: return "ts"
        case .kotlin: return "kt"
        case .java: return "java"
        case .cpp: return "cpp"
        case .c: return "c"
        case .go: return "go"
        case .rust: return "rs"
        case .html: return "html"
        case .css: return "css"
        case .json: return "json"
        case .markdown: return "md"
        case .bash: return "sh"
        case .other: return "txt"
        }
    }

    var icon: String {
        switch self {
        case .swift: return "swift"
        case .python: return "doc.text"
        case .javascript, .typescript: return "j.circle"
        case .kotlin, .java: return "k.circle"
        case .cpp, .c: return "c.circle"
        case .go: return "g.circle"
        case .rust: return "r.circle"
        case .html: return "globe"
        case .css: return "paintbrush"
        case .json: return "curlybraces"
        case .markdown: return "text.alignleft"
        case .bash: return "terminal"
        case .other: return "doc"
        }
    }

    static func fromExtension(_ ext: String) -> ProgrammingLanguage {
        switch ext.lowercased() {
        case "swift": return .swift
        case "py": return .python
        case "js": return .javascript
        case "ts": return .typescript
        case "kt": return .kotlin
        case "java": return .java
        case "cpp", "cc", "cxx": return .cpp
        case "c", "h": return .c
        case "go": return .go
        case "rs": return .rust
        case "html", "htm": return .html
        case "css": return .css
        case "json": return .json
        case "md", "markdown": return .markdown
        case "sh", "bash", "zsh": return .bash
        default: return .other
        }
    }
}
