import os

/// 除錯：log stream --level debug --predicate 'subsystem == "io.github.jackiewu.inputmethod.CodeZhuyin"'
enum Log {
    static let general = Logger(subsystem: "io.github.jackiewu.inputmethod.CodeZhuyin", category: "general")
    static let engine = Logger(subsystem: "io.github.jackiewu.inputmethod.CodeZhuyin", category: "engine")
}
