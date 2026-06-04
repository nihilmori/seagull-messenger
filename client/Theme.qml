pragma Singleton
import QtQuick

QtObject {
    id: theme

    property bool isDark: false

    function toggle() { isDark = !isDark }

    readonly property color bgPrimary:    isDark ? "#0f172a" : "#f5f7fb"
    readonly property color bgSecondary:  isDark ? "#1e293b" : "#ffffff"
    readonly property color bgMuted:      isDark ? "#111827" : "#f0f2f5"
    readonly property color inputBg:      isDark ? "#0b1220" : "#f9fafb"
    readonly property color border:       isDark ? "#334155" : "#e5e7eb"
    readonly property color borderStrong: isDark ? "#475569" : "#d1d5db"

    readonly property color textPrimary:  isDark ? "#f1f5f9" : "#111827"
    readonly property color textBody:     isDark ? "#e2e8f0" : "#374151"
    readonly property color textMuted:    isDark ? "#94a3b8" : "#6b7280"
    readonly property color textFaint:    isDark ? "#64748b" : "#9ca3af"
    readonly property color accent:       isDark ? "#60a5fa" : "#2563eb"

    readonly property color bubbleOut:        isDark ? "#1d4ed8" : "#dbeafe"
    readonly property color bubbleOutBorder:  isDark ? "#3b82f6" : "#93c5fd"
    readonly property color bubbleIn:         isDark ? "#1f2937" : "#f3f4f6"
    readonly property color bubbleInBorder:   isDark ? "#374151" : "#e5e7eb"
    readonly property color bubbleOutText:    isDark ? "#e0ecff" : "#111827"

    readonly property color hover:        isDark ? "#1f2937" : "#e5e7eb"
    readonly property color hoverSubtle:  isDark ? "#1e293b" : "#f3f4f6"
    readonly property color error:        "#dc2626"
    readonly property color success:      isDark ? "#34d399" : "#059669"
}
