import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    signal emojiSelected(string emoji)

    width: 360
    height: 300
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
        radius: 12
        color: "#ffffff"
        border.color: "#e5e7eb"
    }

    readonly property var categories: [
        { icon: "😀", name: "Смайлы", items: [
            "😀","😃","😄","😁","😆","😅","🤣","😂","🙂","🙃","😉","😊","😇","🥰","😍","🤩",
            "😘","😗","😚","😙","😋","😛","😜","🤪","😝","🤑","🤗","🤭","🤫","🤔","🤐","🤨",
            "😐","😑","😶","😏","😒","🙄","😬","🤥","😌","😔","😪","🤤","😴","😷","🤒","🤕",
            "🤢","🤮","🥵","🥶","🥴","😵","🤯","🤠","🥳","😎","🤓","🧐","😕","😟","🙁","😮",
            "😯","😲","😳","🥺","😦","😧","😨","😰","😥","😢","😭","😱","😖","😣","😞","😓"
        ]},
        { icon: "🐶", name: "Животные", items: [
            "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯","🦁","🐮","🐷","🐸","🐵","🙈",
            "🙉","🙊","🐒","🐔","🐧","🐦","🐤","🦄","🐝","🦋","🐌","🐞","🦂","🐢","🐙","🦑",
            "🦐","🦀","🐡","🐠","🐟","🐬","🐳","🐋","🦈","🐊","🐅","🐆","🦓","🦍","🐘","🦏",
            "🐪","🐫","🦒","🐃","🐂","🐄","🐎","🐖","🐏","🐑","🐐","🦌","🐕","🐩","🐈","🦃"
        ]},
        { icon: "🍎", name: "Еда", items: [
            "🍎","🍐","🍊","🍋","🍌","🍉","🍇","🍓","🍈","🍒","🍑","🥭","🍍","🥥","🥝","🍅",
            "🍆","🥑","🥦","🥒","🥕","🌽","🌶","🥔","🍠","🥐","🍞","🥖","🧀","🥚","🍳","🥞",
            "🍔","🍟","🍕","🌭","🥪","🌮","🌯","🥗","🥘","🍝","🍜","🍲","🍛","🍣","🍱","🥟",
            "🍤","🍙","🍚","🍘","🍥","🍢","🍡","🍧","🍨","🍦","🥧","🍰","🎂","🍮","🍭","🍬"
        ]},
        { icon: "⚽", name: "Спорт", items: [
            "⚽","🏀","🏈","⚾","🥎","🎾","🏐","🏉","🥏","🎱","🏓","🏸","🏒","🏑","🥍","🏏",
            "⛳","🏹","🎣","🤿","🥊","🥋","⛸️","🎿","🛷","🥌","🎯","🪀","🪁","🎮","🎲","🧩",
            "🎼","🎤","🎧","🎷","🎸","🪕","🎺","🥁","🚴","🚵","🏇","🏌️","🏄","🏊","🤸","🤾",
            "⛹️","🏋️","🤼","🤺","🤽"
        ]},
        { icon: "🚗", name: "Транспорт", items: [
            "🚗","🚙","🚐","🚛","🚜","🏎️","🚓","🚑","🚒","🚕","🚖","🚌","🚍","🚎","🏍️","🛵",
            "🚲","🛴","🛹","✈️","🛫","🛬","🚀","🛸","🚁","🛰️","⛵","🚤","🛥️","🛳️","🚢","⚓",
            "🚂","🚃","🚄","🚅","🚆","🚇","🚈","🚉","🚊","🚝","🚞","🚋","🚏","⛽","🚦","🚥"
        ]},
        { icon: "💡", name: "Предметы", items: [
            "💎","🔔","🔕","📱","💻","⌨️","🖥️","📷","📸","🎥","📞","☎️","📟","📠","📺","📻",
            "⏰","⏳","⌛","🔋","🔌","💡","🔦","🕯️","🪔","📕","📗","📘","📙","📓","📒","📃",
            "📜","📄","📰","✏️","✒️","🖋️","🖊️","🖌️","🖍️","📝","💼","📁","📂","📅","📆",
            "📇","📈","📉","📊","🔒","🔓","🔏","🔐","🔑","🗝️","🔨","⛏️","🪓","🔧","🔩","⚙️"
        ]},
        { icon: "❤️", name: "Символы", items: [
            "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❣️","💕","💞","💓","💗","💖",
            "💘","💝","💟","💌","💋","💯","💢","💥","💫","💦","💨","💣","💬","💭",
            "🛑","📛","🚫","♻️","✅","❌","⭕","❎","❓","❔","❕",
            "❗","🔱","🔰","⚠️","🚸","🔆","🔅","🆗","🆕","🆙","🆒","🆓","🆖"
        ]},
        { icon: "🎉", name: "Праздник", items: [
            "🎉","🎊","🎈","🎁","🎀","🎗","🎟","🎫","🎖","🏆","🏅","🥇","🥈","🥉","⚽","🏐",
            "🎄","🎃","🎆","🎇","🧨","✨","🎐","🎏","🎑","🎀","🎁","🪅","🪆","🎂","🍰","🧁",
            "🥂","🍾","🍻","🍺","🥃","🍷","🍸","🍹","☕","🍵","🧉","🍶","🧊","🥛","🍼","🫖"
        ]},
        { icon: "🏳️", name: "Флаги", items: [
            "🏁","🚩","🏳️","🏴",
            "🇷🇺","🇺🇸","🇬🇧","🇨🇦","🇦🇺","🇳🇿","🇮🇪",
            "🇫🇷","🇩🇪","🇮🇹","🇪🇸","🇵🇹","🇳🇱","🇧🇪","🇨🇭","🇦🇹","🇸🇪","🇳🇴","🇫🇮","🇩🇰","🇮🇸",
            "🇵🇱","🇨🇿","🇸🇰","🇭🇺","🇷🇴","🇧🇬","🇬🇷","🇭🇷","🇷🇸","🇺🇦","🇧🇾","🇲🇩",
            "🇪🇪","🇱🇻","🇱🇹","🇹🇷","🇨🇾","🇲🇹",
            "🇯🇵","🇨🇳","🇰🇷","🇰🇵","🇮🇳","🇵🇰","🇧🇩","🇱🇰","🇮🇩","🇲🇾","🇸🇬","🇹🇭","🇻🇳","🇵🇭","🇲🇳",
            "🇰🇿","🇺🇿","🇰🇬","🇹🇯","🇹🇲","🇦🇿","🇦🇲","🇬🇪",
            "🇮🇷","🇮🇶","🇸🇦","🇦🇪","🇶🇦","🇰🇼","🇧🇭","🇴🇲","🇾🇪","🇯🇴","🇮🇱","🇱🇧","🇸🇾",
            "🇪🇬","🇲🇦","🇩🇿","🇹🇳","🇱🇾","🇸🇩","🇪🇹","🇰🇪","🇹🇿","🇺🇬","🇳🇬","🇿🇦","🇬🇭","🇸🇳","🇨🇲",
            "🇧🇷","🇦🇷","🇨🇱","🇵🇪","🇨🇴","🇻🇪","🇪🇨","🇧🇴","🇵🇾","🇺🇾","🇲🇽","🇨🇺",
            "🇪🇺","🇺🇳"
        ]}
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        TabBar {
            id: categoryTabs
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            background: Rectangle {
                color: "#f9fafb"
                radius: 12
            }

            Repeater {
                model: root.categories

                TabButton {
                    id: tabBtn
                    required property var modelData
                    width: implicitWidth
                    padding: 4

                    background: Rectangle {
                        color: tabBtn.checked ? "#dbeafe" : (tabBtn.hovered ? "#e5e7eb" : "transparent")
                        radius: 8
                    }

                    contentItem: Text {
                        text: tabBtn.modelData.icon
                        font.pixelSize: 20
                        font.family: "Noto Color Emoji"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"

            StackLayout {
                anchors.fill: parent
                anchors.margins: 6
                currentIndex: categoryTabs.currentIndex

                Repeater {
                    model: root.categories

                    GridView {
                        required property var modelData
                        clip: true
                        cellWidth: 36
                        cellHeight: 36
                        model: modelData.items
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property string modelData
                            width: 36
                            height: 36
                            radius: 6
                            color: cellMouseArea.containsMouse ? "#f3f4f6" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.pixelSize: 22
                                font.family: "Noto Color Emoji"
                            }

                            MouseArea {
                                id: cellMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.emojiSelected(parent.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
