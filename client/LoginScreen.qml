import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient
import "ApiClient.js" as WebApi

Rectangle {
    id: loginRoot
    anchors.fill: parent
    color: Theme.bgMuted

    property bool isRegisterMode: false
    property bool passwordVisible: false
    property var appStateRef

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 18
        width: Math.min(parent.width * 0.8, 360)

        Text {
            text: isRegisterMode ? "Регистрация" : "Вход"
            font.pixelSize: 30
            font.bold: true
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: nameField
            placeholderText: "Ваше имя"
            visible: isRegisterMode
            Layout.fillWidth: true
            padding: 10
            color: Theme.textPrimary
            placeholderTextColor: Theme.textFaint
            background: Rectangle {
                radius: 12
                color: Theme.bgSecondary
                border.color: Theme.border
            }
        }

        TextField {
            id: loginField
            placeholderText: "Логин"
            Layout.fillWidth: true
            selectByMouse: true
            padding: 10
            color: Theme.textPrimary
            placeholderTextColor: Theme.textFaint
            background: Rectangle {
                radius: 12
                color: Theme.bgSecondary
                border.color: Theme.border
            }
            onAccepted: authButton.clicked()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: passwordField
                placeholderText: "Пароль"
                echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
                Layout.fillWidth: true
                selectByMouse: true
                padding: 10
                color: Theme.textPrimary
                placeholderTextColor: Theme.textFaint
                background: Rectangle {
                    radius: 12
                    color: Theme.bgSecondary
                    border.color: Theme.border
                }
                onAccepted: authButton.clicked()
            }

            Button {
                id: togglePasswordButton
                text: passwordVisible ? "Скрыть" : "Показать"
                padding: 10
                palette.buttonText: Theme.textPrimary
                background: Rectangle {
                    radius: 12
                    color: togglePasswordButton.hovered ? Theme.hover : Theme.hoverSubtle
                    border.color: Theme.borderStrong
                }
                onClicked: passwordVisible = !passwordVisible
            }
        }

        ColumnLayout {
            visible: isRegisterMode
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: "Требования к паролю:"
                font.pixelSize: 12
                color: Theme.textMuted
            }
            Text {
                text: "• от 8 до 32 символов"
                font.pixelSize: 12
                color: (passwordField.text.length >= 8 && passwordField.text.length <= 32) ? Theme.success : Theme.textFaint
            }
            Text {
                text: "• заглавная буква"
                font.pixelSize: 12
                color: /[A-Z]/.test(passwordField.text) ? Theme.success : Theme.textFaint
            }
            Text {
                text: "• строчная буква"
                font.pixelSize: 12
                color: /[a-z]/.test(passwordField.text) ? Theme.success : Theme.textFaint
            }
            Text {
                text: "• цифра"
                font.pixelSize: 12
                color: /[0-9]/.test(passwordField.text) ? Theme.success : Theme.textFaint
            }
            Text {
                text: "• без пробелов"
                font.pixelSize: 12
                color: (passwordField.text.length > 0 && !/\s/.test(passwordField.text)) ? Theme.success : Theme.textFaint
            }
        }

        Button {
            id: authButton
            text: isRegisterMode ? "Создать аккаунт" : "Войти"
            Layout.fillWidth: true
            padding: 10
            palette.buttonText: Theme.bubbleOutText
            background: Rectangle {
                radius: 12
                color: authButton.hovered ? Theme.bubbleOutBorder : Theme.bubbleOut
                border.color: Theme.bubbleOutBorder
            }
            onClicked: {
                errorLabel.text = ""
                if (isRegisterMode) {
                    WebApi.ApiClient.register(loginField.text, passwordField.text, nameField.text, function(status, response) {
                        if (status === 201) {
                            errorLabel.color = Theme.success
                            errorLabel.text = "Регистрация успешна"
                            isRegisterMode = false
                            nameField.text = ""
                            loginField.text = ""
                            passwordField.text = ""
                        } else {
                            errorLabel.color = Theme.error
                            errorLabel.text = "Ошибка регистрации: " + (response.error || status)
                        }
                    })
                } else {
                    WebApi.ApiClient.login(loginField.text, passwordField.text, function(status, response) {
                        if (status === 200) {
                            appStateRef.currentUserId = response.user_id
                            appStateRef.currentLogin = response.login
                            appStateRef.currentName = response.name
                            appStateRef.isLoggedIn = true
                        } else {
                            errorLabel.color = Theme.error
                            errorLabel.text = "Ошибка входа: " + (response.error || status)
                        }
                    })
                }
            }
        }

        Text {
            text: isRegisterMode ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Регистрация"
            color: Theme.accent
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    isRegisterMode = !isRegisterMode
                    errorLabel.text = ""
                }
            }
        }

        Text {
            id: errorLabel
            color: Theme.error
            font.pixelSize: 14
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
