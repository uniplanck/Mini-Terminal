import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ja
    case zhHans
    case zhHant
    case ko
    case es
    case fr
    case de
    case pt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .ko: return "한국어"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .pt: return "Português"
        }
    }

    static func fromPreferredLanguage(_ identifier: String) -> AppLanguage? {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if normalized.hasPrefix("zh-hant")
            || normalized.hasPrefix("zh-tw")
            || normalized.hasPrefix("zh-hk")
            || normalized.hasPrefix("zh-mo") {
            return .zhHant
        }
        if normalized.hasPrefix("zh") { return .zhHans }
        if normalized.hasPrefix("ja") { return .ja }
        if normalized.hasPrefix("ko") { return .ko }
        if normalized.hasPrefix("es") { return .es }
        if normalized.hasPrefix("fr") { return .fr }
        if normalized.hasPrefix("de") { return .de }
        if normalized.hasPrefix("pt") { return .pt }
        if normalized.hasPrefix("en") { return .en }
        return nil
    }

    static func systemPreferred() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            if let language = fromPreferredLanguage(identifier) {
                return language
            }
        }
        return .en
    }
}

enum L10n {
    enum Key: String {
        case menuOpen
        case menuSettings
        case menuQuit
        case settingsTitle

        case languageSection
        case languageLabel
        case languageSystemHelp

        case shortcutSection
        case shortcutOpen
        case shortcutWaiting
        case shortcutHelp

        case clipboardSection
        case clipboardPaste
        case clipboardAutoRun
        case clipboardCopyOutput

        case safetySection
        case safetyConfirm
        case safetyHelp

        case shellSection
        case workingDirectory
        case shellTildeHelp

        case executionConfirmTitle
        case cancel
        case run
        case executionConfirmMessage

        case shellCommandPlaceholder
        case history
        case launchAutoRunOn
        case launchAutoRunOff
        case compactView
        case splitView
        case settings
        case historyEmpty
        case clearHistory
        case inputTitle
        case outputTitle
        case copyInput
        case copyOutput
        case copyBoth
        case running
        case outputPlaceholder

        case copyInputFeedback
        case copyOutputFeedback
        case copyBothFeedback
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let resolved = language == .system ? AppLanguage.systemPreferred() : language
        return tables[resolved]?[key] ?? tables[.en]?[key] ?? key.rawValue
    }

    static func historyCount(_ count: Int, language: AppLanguage) -> String {
        let resolved = language == .system ? AppLanguage.systemPreferred() : language
        switch resolved {
        case .ja:
            return "\(count)件"
        case .zhHans, .zhHant:
            return "\(count) 条"
        case .ko:
            return "\(count)개"
        case .es:
            return "\(count) elementos"
        case .fr:
            return "\(count) éléments"
        case .de:
            return "\(count) Einträge"
        case .pt:
            return "\(count) itens"
        case .en, .system:
            return count == 1 ? "1 item" : "\(count) items"
        }
    }

    private static let tables: [AppLanguage: [Key: String]] = [
        .en: [
            .menuOpen: "Open Mini-Terminal",
            .menuSettings: "Settings…",
            .menuQuit: "Quit",
            .settingsTitle: "Mini-Terminal Settings",
            .languageSection: "Language",
            .languageLabel: "App language",
            .languageSystemHelp: "System follows the first supported language in macOS. Unsupported languages fall back to English.",
            .shortcutSection: "Shortcut",
            .shortcutOpen: "Open Mini-Terminal",
            .shortcutWaiting: "Press keys…",
            .shortcutHelp: "Click the shortcut button, then press a shortcut with at least one modifier. Press Esc to cancel.",
            .clipboardSection: "Clipboard",
            .clipboardPaste: "Paste clipboard content when opened",
            .clipboardAutoRun: "Run clipboard content immediately when opened",
            .clipboardCopyOutput: "Copy command output to the clipboard after execution",
            .safetySection: "Safety",
            .safetyConfirm: "Confirm potentially dangerous and multi-line commands before running",
            .safetyHelp: "Recommended when auto-run is enabled. Detects commands such as rm, sudo, and git reset --hard.",
            .shellSection: "Shell",
            .workingDirectory: "Working directory",
            .shellTildeHelp: "~ expands to your home directory.",
            .executionConfirmTitle: "Confirm execution",
            .cancel: "Cancel",
            .run: "Run",
            .executionConfirmMessage: "This looks destructive, privileged, or multi-line. Check the command before running it.",
            .shellCommandPlaceholder: "Shell command…",
            .history: "Execution history",
            .launchAutoRunOn: "Run clipboard on open: ON",
            .launchAutoRunOff: "Run clipboard on open: OFF",
            .compactView: "Compact view",
            .splitView: "Split input / output",
            .settings: "Settings",
            .historyEmpty: "No execution history yet",
            .clearHistory: "Clear history",
            .inputTitle: "INPUT",
            .outputTitle: "OUTPUT",
            .copyInput: "Copy input",
            .copyOutput: "Copy output",
            .copyBoth: "Copy input + output",
            .running: "Running…",
            .outputPlaceholder: "Command output appears here",
            .copyInputFeedback: "Input copied",
            .copyOutputFeedback: "Output copied",
            .copyBothFeedback: "Input + output copied"
        ],
        .ja: [
            .menuOpen: "Mini-Terminalを開く",
            .menuSettings: "設定…",
            .menuQuit: "終了",
            .settingsTitle: "Mini-Terminal 設定",
            .languageSection: "言語",
            .languageLabel: "アプリの言語",
            .languageSystemHelp: "SystemではmacOSの優先言語に追従します。未対応の言語では英語を使用します。",
            .shortcutSection: "ショートカット",
            .shortcutOpen: "Mini-Terminalを開く",
            .shortcutWaiting: "キー入力待ち…",
            .shortcutHelp: "ボタンを押してから、修飾キーを含むショートカットを入力します。Escでキャンセルできます。",
            .clipboardSection: "クリップボード",
            .clipboardPaste: "開いたときクリップボードを入力欄へ貼り付ける",
            .clipboardAutoRun: "起動時にクリップボード内容をそのまま実行する",
            .clipboardCopyOutput: "実行後に出力をクリップボードへコピーする",
            .safetySection: "安全",
            .safetyConfirm: "危険なコマンドと複数行コマンドは実行前に確認する",
            .safetyHelp: "自動実行を使う場合はON推奨です。rm / sudo / git reset --hard などを検出します。",
            .shellSection: "Shell",
            .workingDirectory: "作業ディレクトリ",
            .shellTildeHelp: "~ はホームディレクトリとして展開されます。",
            .executionConfirmTitle: "実行確認",
            .cancel: "キャンセル",
            .run: "実行",
            .executionConfirmMessage: "破壊的、権限昇格、または複数行のコマンドとして検出しました。内容を確認してから実行してください。",
            .shellCommandPlaceholder: "Shell command…",
            .history: "実行履歴",
            .launchAutoRunOn: "起動時にClipboardを即実行: ON",
            .launchAutoRunOff: "起動時にClipboardを即実行: OFF",
            .compactView: "コンパクト表示",
            .splitView: "入出力を分割表示",
            .settings: "設定",
            .historyEmpty: "実行履歴はまだありません",
            .clearHistory: "履歴を消去",
            .inputTitle: "入力",
            .outputTitle: "出力",
            .copyInput: "入力をコピー",
            .copyOutput: "出力をコピー",
            .copyBoth: "入出力をコピー",
            .running: "実行中…",
            .outputPlaceholder: "実行結果はここに表示されます",
            .copyInputFeedback: "入力をコピーしました",
            .copyOutputFeedback: "出力をコピーしました",
            .copyBothFeedback: "入出力をコピーしました"
        ],
        .zhHans: [
            .menuOpen: "打开 Mini-Terminal",
            .menuSettings: "设置…",
            .menuQuit: "退出",
            .settingsTitle: "Mini-Terminal 设置",
            .languageSection: "语言",
            .languageLabel: "应用语言",
            .languageSystemHelp: "System 会跟随 macOS 中首个受支持的首选语言。不支持的语言将使用英语。",
            .shortcutSection: "快捷键",
            .shortcutOpen: "打开 Mini-Terminal",
            .shortcutWaiting: "请按快捷键…",
            .shortcutHelp: "点击按钮后输入包含至少一个修饰键的快捷键。按 Esc 取消。",
            .clipboardSection: "剪贴板",
            .clipboardPaste: "打开时将剪贴板内容粘贴到输入框",
            .clipboardAutoRun: "打开时立即运行剪贴板内容",
            .clipboardCopyOutput: "执行后将输出复制到剪贴板",
            .safetySection: "安全",
            .safetyConfirm: "运行危险或多行命令前进行确认",
            .safetyHelp: "启用自动运行时建议开启。会检测 rm、sudo、git reset --hard 等命令。",
            .shellSection: "Shell",
            .workingDirectory: "工作目录",
            .shellTildeHelp: "~ 会展开为你的主目录。",
            .executionConfirmTitle: "确认执行",
            .cancel: "取消",
            .run: "运行",
            .executionConfirmMessage: "检测到可能具有破坏性、需要提权或包含多行的命令。请确认内容后再运行。",
            .shellCommandPlaceholder: "Shell 命令…",
            .history: "执行历史",
            .launchAutoRunOn: "打开时运行剪贴板：开",
            .launchAutoRunOff: "打开时运行剪贴板：关",
            .compactView: "紧凑视图",
            .splitView: "拆分输入 / 输出",
            .settings: "设置",
            .historyEmpty: "暂无执行历史",
            .clearHistory: "清除历史",
            .inputTitle: "输入",
            .outputTitle: "输出",
            .copyInput: "复制输入",
            .copyOutput: "复制输出",
            .copyBoth: "复制输入和输出",
            .running: "运行中…",
            .outputPlaceholder: "命令输出将显示在这里",
            .copyInputFeedback: "已复制输入",
            .copyOutputFeedback: "已复制输出",
            .copyBothFeedback: "已复制输入和输出"
        ],
        .zhHant: [
            .menuOpen: "開啟 Mini-Terminal",
            .menuSettings: "設定…",
            .menuQuit: "結束",
            .settingsTitle: "Mini-Terminal 設定",
            .languageSection: "語言",
            .languageLabel: "App 語言",
            .languageSystemHelp: "System 會跟隨 macOS 中第一個支援的偏好語言。不支援的語言將使用英文。",
            .shortcutSection: "快速鍵",
            .shortcutOpen: "開啟 Mini-Terminal",
            .shortcutWaiting: "請按快速鍵…",
            .shortcutHelp: "按下按鈕後輸入至少包含一個修飾鍵的快速鍵。按 Esc 取消。",
            .clipboardSection: "剪貼簿",
            .clipboardPaste: "開啟時將剪貼簿內容貼到輸入欄",
            .clipboardAutoRun: "開啟時立即執行剪貼簿內容",
            .clipboardCopyOutput: "執行後將輸出複製到剪貼簿",
            .safetySection: "安全",
            .safetyConfirm: "執行危險或多行命令前先確認",
            .safetyHelp: "使用自動執行時建議開啟。會偵測 rm、sudo、git reset --hard 等命令。",
            .shellSection: "Shell",
            .workingDirectory: "工作目錄",
            .shellTildeHelp: "~ 會展開為你的家目錄。",
            .executionConfirmTitle: "確認執行",
            .cancel: "取消",
            .run: "執行",
            .executionConfirmMessage: "偵測到可能具有破壞性、需要提升權限或包含多行的命令。請確認內容後再執行。",
            .shellCommandPlaceholder: "Shell 命令…",
            .history: "執行記錄",
            .launchAutoRunOn: "開啟時執行剪貼簿：開",
            .launchAutoRunOff: "開啟時執行剪貼簿：關",
            .compactView: "精簡檢視",
            .splitView: "分割輸入 / 輸出",
            .settings: "設定",
            .historyEmpty: "尚無執行記錄",
            .clearHistory: "清除記錄",
            .inputTitle: "輸入",
            .outputTitle: "輸出",
            .copyInput: "複製輸入",
            .copyOutput: "複製輸出",
            .copyBoth: "複製輸入與輸出",
            .running: "執行中…",
            .outputPlaceholder: "命令輸出會顯示在這裡",
            .copyInputFeedback: "已複製輸入",
            .copyOutputFeedback: "已複製輸出",
            .copyBothFeedback: "已複製輸入與輸出"
        ],
        .ko: [
            .menuOpen: "Mini-Terminal 열기",
            .menuSettings: "설정…",
            .menuQuit: "종료",
            .settingsTitle: "Mini-Terminal 설정",
            .languageSection: "언어",
            .languageLabel: "앱 언어",
            .languageSystemHelp: "System은 macOS의 우선 언어 중 지원되는 첫 언어를 사용합니다. 지원하지 않는 언어는 영어로 표시됩니다.",
            .shortcutSection: "단축키",
            .shortcutOpen: "Mini-Terminal 열기",
            .shortcutWaiting: "키 입력 대기…",
            .shortcutHelp: "버튼을 누른 뒤 하나 이상의 보조 키가 포함된 단축키를 입력하세요. Esc로 취소할 수 있습니다.",
            .clipboardSection: "클립보드",
            .clipboardPaste: "열 때 클립보드 내용을 입력란에 붙여넣기",
            .clipboardAutoRun: "열 때 클립보드 내용을 즉시 실행",
            .clipboardCopyOutput: "실행 후 출력을 클립보드에 복사",
            .safetySection: "안전",
            .safetyConfirm: "위험하거나 여러 줄인 명령은 실행 전에 확인",
            .safetyHelp: "자동 실행 사용 시 켜는 것을 권장합니다. rm, sudo, git reset --hard 등을 감지합니다.",
            .shellSection: "Shell",
            .workingDirectory: "작업 디렉터리",
            .shellTildeHelp: "~ 는 홈 디렉터리로 확장됩니다.",
            .executionConfirmTitle: "실행 확인",
            .cancel: "취소",
            .run: "실행",
            .executionConfirmMessage: "파괴적이거나 권한 상승이 필요하거나 여러 줄인 명령으로 감지했습니다. 내용을 확인한 뒤 실행하세요.",
            .shellCommandPlaceholder: "Shell 명령…",
            .history: "실행 기록",
            .launchAutoRunOn: "열 때 클립보드 실행: 켬",
            .launchAutoRunOff: "열 때 클립보드 실행: 끔",
            .compactView: "컴팩트 보기",
            .splitView: "입력 / 출력 분할",
            .settings: "설정",
            .historyEmpty: "실행 기록이 없습니다",
            .clearHistory: "기록 지우기",
            .inputTitle: "입력",
            .outputTitle: "출력",
            .copyInput: "입력 복사",
            .copyOutput: "출력 복사",
            .copyBoth: "입력 + 출력 복사",
            .running: "실행 중…",
            .outputPlaceholder: "명령 출력이 여기에 표시됩니다",
            .copyInputFeedback: "입력을 복사했습니다",
            .copyOutputFeedback: "출력을 복사했습니다",
            .copyBothFeedback: "입력과 출력을 복사했습니다"
        ],
        .es: [
            .menuOpen: "Abrir Mini-Terminal",
            .menuSettings: "Ajustes…",
            .menuQuit: "Salir",
            .settingsTitle: "Ajustes de Mini-Terminal",
            .languageSection: "Idioma",
            .languageLabel: "Idioma de la app",
            .languageSystemHelp: "System usa el primer idioma compatible de macOS. Los idiomas no compatibles usan inglés.",
            .shortcutSection: "Atajo",
            .shortcutOpen: "Abrir Mini-Terminal",
            .shortcutWaiting: "Pulsa las teclas…",
            .shortcutHelp: "Pulsa el botón y luego un atajo con al menos una tecla modificadora. Esc cancela.",
            .clipboardSection: "Portapapeles",
            .clipboardPaste: "Pegar el portapapeles al abrir",
            .clipboardAutoRun: "Ejecutar el contenido del portapapeles al abrir",
            .clipboardCopyOutput: "Copiar la salida al portapapeles tras ejecutar",
            .safetySection: "Seguridad",
            .safetyConfirm: "Confirmar comandos peligrosos o multilínea antes de ejecutar",
            .safetyHelp: "Recomendado con la ejecución automática. Detecta rm, sudo, git reset --hard y otros comandos.",
            .shellSection: "Shell",
            .workingDirectory: "Directorio de trabajo",
            .shellTildeHelp: "~ se expande al directorio personal.",
            .executionConfirmTitle: "Confirmar ejecución",
            .cancel: "Cancelar",
            .run: "Ejecutar",
            .executionConfirmMessage: "El comando parece destructivo, privilegiado o multilínea. Revísalo antes de ejecutarlo.",
            .shellCommandPlaceholder: "Comando de Shell…",
            .history: "Historial de ejecución",
            .launchAutoRunOn: "Ejecutar portapapeles al abrir: SÍ",
            .launchAutoRunOff: "Ejecutar portapapeles al abrir: NO",
            .compactView: "Vista compacta",
            .splitView: "Separar entrada / salida",
            .settings: "Ajustes",
            .historyEmpty: "Aún no hay historial",
            .clearHistory: "Borrar historial",
            .inputTitle: "ENTRADA",
            .outputTitle: "SALIDA",
            .copyInput: "Copiar entrada",
            .copyOutput: "Copiar salida",
            .copyBoth: "Copiar entrada + salida",
            .running: "Ejecutando…",
            .outputPlaceholder: "La salida del comando aparecerá aquí",
            .copyInputFeedback: "Entrada copiada",
            .copyOutputFeedback: "Salida copiada",
            .copyBothFeedback: "Entrada y salida copiadas"
        ],
        .fr: [
            .menuOpen: "Ouvrir Mini-Terminal",
            .menuSettings: "Réglages…",
            .menuQuit: "Quitter",
            .settingsTitle: "Réglages de Mini-Terminal",
            .languageSection: "Langue",
            .languageLabel: "Langue de l’app",
            .languageSystemHelp: "System utilise la première langue macOS prise en charge. Les autres langues utilisent l’anglais.",
            .shortcutSection: "Raccourci",
            .shortcutOpen: "Ouvrir Mini-Terminal",
            .shortcutWaiting: "Appuyez sur les touches…",
            .shortcutHelp: "Cliquez sur le bouton puis saisissez un raccourci avec au moins une touche de modification. Esc annule.",
            .clipboardSection: "Presse-papiers",
            .clipboardPaste: "Coller le presse-papiers à l’ouverture",
            .clipboardAutoRun: "Exécuter immédiatement le presse-papiers à l’ouverture",
            .clipboardCopyOutput: "Copier la sortie dans le presse-papiers après exécution",
            .safetySection: "Sécurité",
            .safetyConfirm: "Confirmer les commandes dangereuses ou multilignes avant exécution",
            .safetyHelp: "Recommandé avec l’exécution automatique. Détecte rm, sudo, git reset --hard, etc.",
            .shellSection: "Shell",
            .workingDirectory: "Dossier de travail",
            .shellTildeHelp: "~ correspond à votre dossier personnel.",
            .executionConfirmTitle: "Confirmer l’exécution",
            .cancel: "Annuler",
            .run: "Exécuter",
            .executionConfirmMessage: "Cette commande semble destructive, privilégiée ou multiligne. Vérifiez-la avant de l’exécuter.",
            .shellCommandPlaceholder: "Commande Shell…",
            .history: "Historique d’exécution",
            .launchAutoRunOn: "Exécuter le presse-papiers à l’ouverture : OUI",
            .launchAutoRunOff: "Exécuter le presse-papiers à l’ouverture : NON",
            .compactView: "Vue compacte",
            .splitView: "Séparer entrée / sortie",
            .settings: "Réglages",
            .historyEmpty: "Aucun historique pour le moment",
            .clearHistory: "Effacer l’historique",
            .inputTitle: "ENTRÉE",
            .outputTitle: "SORTIE",
            .copyInput: "Copier l’entrée",
            .copyOutput: "Copier la sortie",
            .copyBoth: "Copier entrée + sortie",
            .running: "Exécution…",
            .outputPlaceholder: "La sortie de la commande apparaîtra ici",
            .copyInputFeedback: "Entrée copiée",
            .copyOutputFeedback: "Sortie copiée",
            .copyBothFeedback: "Entrée et sortie copiées"
        ],
        .de: [
            .menuOpen: "Mini-Terminal öffnen",
            .menuSettings: "Einstellungen…",
            .menuQuit: "Beenden",
            .settingsTitle: "Mini-Terminal Einstellungen",
            .languageSection: "Sprache",
            .languageLabel: "App-Sprache",
            .languageSystemHelp: "System verwendet die erste unterstützte macOS-Sprache. Nicht unterstützte Sprachen verwenden Englisch.",
            .shortcutSection: "Tastenkürzel",
            .shortcutOpen: "Mini-Terminal öffnen",
            .shortcutWaiting: "Tasten drücken…",
            .shortcutHelp: "Klicken Sie auf die Schaltfläche und drücken Sie ein Kürzel mit mindestens einer Sondertaste. Esc bricht ab.",
            .clipboardSection: "Zwischenablage",
            .clipboardPaste: "Zwischenablage beim Öffnen einfügen",
            .clipboardAutoRun: "Zwischenablage beim Öffnen sofort ausführen",
            .clipboardCopyOutput: "Ausgabe nach der Ausführung in die Zwischenablage kopieren",
            .safetySection: "Sicherheit",
            .safetyConfirm: "Potenziell gefährliche und mehrzeilige Befehle vor der Ausführung bestätigen",
            .safetyHelp: "Bei Auto-Run empfohlen. Erkennt unter anderem rm, sudo und git reset --hard.",
            .shellSection: "Shell",
            .workingDirectory: "Arbeitsverzeichnis",
            .shellTildeHelp: "~ wird zum Benutzerordner erweitert.",
            .executionConfirmTitle: "Ausführung bestätigen",
            .cancel: "Abbrechen",
            .run: "Ausführen",
            .executionConfirmMessage: "Der Befehl wirkt destruktiv, privilegiert oder mehrzeilig. Bitte vor der Ausführung prüfen.",
            .shellCommandPlaceholder: "Shell-Befehl…",
            .history: "Ausführungsverlauf",
            .launchAutoRunOn: "Zwischenablage beim Öffnen ausführen: AN",
            .launchAutoRunOff: "Zwischenablage beim Öffnen ausführen: AUS",
            .compactView: "Kompakte Ansicht",
            .splitView: "Eingabe / Ausgabe teilen",
            .settings: "Einstellungen",
            .historyEmpty: "Noch kein Ausführungsverlauf",
            .clearHistory: "Verlauf löschen",
            .inputTitle: "EINGABE",
            .outputTitle: "AUSGABE",
            .copyInput: "Eingabe kopieren",
            .copyOutput: "Ausgabe kopieren",
            .copyBoth: "Eingabe + Ausgabe kopieren",
            .running: "Wird ausgeführt…",
            .outputPlaceholder: "Die Befehlsausgabe erscheint hier",
            .copyInputFeedback: "Eingabe kopiert",
            .copyOutputFeedback: "Ausgabe kopiert",
            .copyBothFeedback: "Eingabe und Ausgabe kopiert"
        ],
        .pt: [
            .menuOpen: "Abrir Mini-Terminal",
            .menuSettings: "Ajustes…",
            .menuQuit: "Sair",
            .settingsTitle: "Ajustes do Mini-Terminal",
            .languageSection: "Idioma",
            .languageLabel: "Idioma do app",
            .languageSystemHelp: "System usa o primeiro idioma compatível do macOS. Idiomas não compatíveis usam inglês.",
            .shortcutSection: "Atalho",
            .shortcutOpen: "Abrir Mini-Terminal",
            .shortcutWaiting: "Pressione as teclas…",
            .shortcutHelp: "Clique no botão e pressione um atalho com pelo menos uma tecla modificadora. Esc cancela.",
            .clipboardSection: "Área de transferência",
            .clipboardPaste: "Colar a área de transferência ao abrir",
            .clipboardAutoRun: "Executar a área de transferência imediatamente ao abrir",
            .clipboardCopyOutput: "Copiar a saída para a área de transferência após executar",
            .safetySection: "Segurança",
            .safetyConfirm: "Confirmar comandos perigosos ou com várias linhas antes de executar",
            .safetyHelp: "Recomendado com execução automática. Detecta rm, sudo, git reset --hard e outros comandos.",
            .shellSection: "Shell",
            .workingDirectory: "Diretório de trabalho",
            .shellTildeHelp: "~ expande para o diretório pessoal.",
            .executionConfirmTitle: "Confirmar execução",
            .cancel: "Cancelar",
            .run: "Executar",
            .executionConfirmMessage: "O comando parece destrutivo, privilegiado ou multilinha. Revise antes de executar.",
            .shellCommandPlaceholder: "Comando Shell…",
            .history: "Histórico de execução",
            .launchAutoRunOn: "Executar área de transferência ao abrir: ATIVADO",
            .launchAutoRunOff: "Executar área de transferência ao abrir: DESATIVADO",
            .compactView: "Visualização compacta",
            .splitView: "Separar entrada / saída",
            .settings: "Ajustes",
            .historyEmpty: "Ainda não há histórico",
            .clearHistory: "Limpar histórico",
            .inputTitle: "ENTRADA",
            .outputTitle: "SAÍDA",
            .copyInput: "Copiar entrada",
            .copyOutput: "Copiar saída",
            .copyBoth: "Copiar entrada + saída",
            .running: "Executando…",
            .outputPlaceholder: "A saída do comando aparecerá aqui",
            .copyInputFeedback: "Entrada copiada",
            .copyOutputFeedback: "Saída copiada",
            .copyBothFeedback: "Entrada e saída copiadas"
        ]
    ]
}
