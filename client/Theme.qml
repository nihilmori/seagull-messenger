pragma Singleton
import QtQuick

QtObject {
    id: theme

    property bool isDark: false

    function toggle() { isDark = !isDark }

    readonly property color bgPrimary:    isDark ? "#17212b" : "#f5f7fb"
    readonly property color bgSecondary:  isDark ? "#182533" : "#ffffff"
    readonly property color bgMuted:      isDark ? "#0e1621" : "#f0f2f5"
    readonly property color inputBg:      isDark ? "#24303f" : "#f9fafb"
    readonly property color border:       isDark ? "#101924" : "#e5e7eb"
    readonly property color borderStrong: isDark ? "#2b394a" : "#d1d5db"

    readonly property color textPrimary:  isDark ? "#f5f5f5" : "#111827"
    readonly property color textBody:     isDark ? "#e5edff" : "#374151"
    readonly property color textMuted:    isDark ? "#7f91a4" : "#6b7280"
    readonly property color textFaint:    isDark ? "#6c7883" : "#9ca3af"
    readonly property color accent:       isDark ? "#5288c1" : "#2563eb"

    readonly property color bubbleOut:        isDark ? "#2b5278" : "#dbeafe"
    readonly property color bubbleOutBorder:  isDark ? "#2b5278" : "#93c5fd"
    readonly property color bubbleIn:         isDark ? "#182533" : "#f3f4f6"
    readonly property color bubbleInBorder:   isDark ? "#182533" : "#e5e7eb"
    readonly property color bubbleOutText:    isDark ? "#ffffff" : "#111827"

    readonly property color hover:        isDark ? "#202b36" : "#e5e7eb"
    readonly property color hoverSubtle:  isDark ? "#1c2937" : "#f3f4f6"
    readonly property color error:        isDark ? "#ec3942" : "#dc2626"
    readonly property color success:      isDark ? "#46b660" : "#059669"
}
