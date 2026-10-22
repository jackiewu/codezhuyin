/// 系統詞典（/usr/share/dict/words，1934 年的 Webster）沒有的現代與技術用詞。
/// 少了它們，google 會被當成「goo＋注音」拆錯。只放 3 個字母以上的詞（短詞容易撞到注音）。
public enum TechWords {
    public static let list: [String] = [
        // 公司、產品、服務
        "google", "gmail", "youtube", "github", "gitlab", "bitbucket", "facebook", "instagram", "twitter",
        "linkedin", "slack", "discord", "notion", "figma", "jira", "confluence", "trello", "zoom", "teams",
        "microsoft", "windows", "linux", "ubuntu", "debian", "fedora", "macos", "ios", "ipados", "android",
        "iphone", "ipad", "macbook", "imac", "airpods", "xcode", "vscode", "intellij", "chrome", "safari",
        "firefox", "openai", "chatgpt", "claude", "anthropic", "gemini", "copilot", "netflix", "spotify",
        "amazon", "aws", "azure", "gcp", "cloudflare", "vercel", "netlify", "heroku", "firebase", "supabase",
        "stripe", "paypal", "shopify", "wordpress", "line", "telegram", "whatsapp", "wechat", "uber",
        // 語言、框架、工具
        "python", "javascript", "typescript", "swift", "kotlin", "golang", "rust", "java", "ruby", "php",
        "perl", "scala", "haskell", "elixir", "dart", "flutter", "react", "vue", "angular", "svelte",
        "nextjs", "nuxt", "node", "nodejs", "deno", "bun", "npm", "npx", "pnpm", "yarn", "pip", "conda",
        "brew", "homebrew", "cargo", "gradle", "maven", "webpack", "vite", "babel", "eslint", "prettier",
        "docker", "kubernetes", "kubectl", "helm", "terraform", "ansible", "jenkins", "nginx", "apache",
        "redis", "mysql", "postgres", "postgresql", "sqlite", "mongodb", "kafka", "rabbitmq", "graphql",
        "django", "flask", "fastapi", "rails", "laravel", "spring", "express", "tailwind", "bootstrap",
        "jquery", "pandas", "numpy", "pytorch", "tensorflow", "jupyter", "llama", "ollama", "huggingface",
        "git", "ssh", "sudo", "bash", "zsh", "vim", "neovim", "emacs", "tmux", "curl", "wget", "grep",
        "awk", "sed", "make", "cmake", "gcc", "clang", "llvm",
        // 常見技術詞
        "api", "apis", "sdk", "cli", "gui", "url", "uri", "http", "https", "json", "yaml", "toml", "xml",
        "html", "css", "scss", "sql", "nosql", "regex", "utf", "ascii", "unicode", "markdown", "readme",
        "repo", "repos", "commit", "commits", "branch", "merge", "rebase", "pull", "push", "fork", "clone",
        "deploy", "deployment", "release", "hotfix", "bugfix", "debug", "debugger", "refactor", "lint",
        "frontend", "backend", "fullstack", "devops", "localhost", "endpoint", "webhook", "middleware",
        "async", "await", "callback", "promise", "struct", "enum", "func", "lambda", "boolean", "bool",
        "int", "float", "string", "null", "nil", "undefined", "true", "false", "const", "var", "let",
        "import", "export", "return", "class", "interface", "protocol", "config", "env", "dotenv",
        "token", "tokens", "oauth", "jwt", "login", "logout", "signup", "admin", "dashboard", "plugin",
        "plugins", "app", "apps", "email", "emails", "online", "offline", "wifi", "bluetooth", "usb",
        "cpu", "gpu", "ram", "ssd", "llm", "llms", "prompt", "prompts", "chatbot", "dataset", "pipeline",
        "workflow", "backlog", "sprint", "standup", "kpi", "okr", "demo", "mvp", "pdf", "png", "jpg",
        "jpeg", "svg", "gif", "csv", "zip", "localhost", "cpp", "golang", "dockerfile", "makefile",
    ]
}
