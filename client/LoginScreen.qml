import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ApiClient.js" as WebApi

Rectangle {
    id: loginRoot
    anchors.fill: parent
    color: "#f0f2f5"

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
            color: "#1f2937"
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: nameField
            placeholderText: "Ваше имя"
            visible: isRegisterMode
            Layout.fillWidth: true
            padding: 10
            color: "#111827"
            placeholderTextColor: "#9ca3af"
            background: Rectangle {
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
            }
        }

        TextField {
            id: loginField
            placeholderText: "Логин"
            Layout.fillWidth: true
            selectByMouse: true
            padding: 10
            color: "#111827"
            placeholderTextColor: "#9ca3af"
            background: Rectangle {
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
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
                color: "#111827"
                placeholderTextColor: "#9ca3af"
                background: Rectangle {
                    radius: 12
                    color: "#ffffff"
                    border.color: "#e5e7eb"
                }
                onAccepted: authButton.clicked()
            }

            Button {
                id: togglePasswordButton
                text: passwordVisible ? "Скрыть" : "Показать"
                padding: 10
                palette.buttonText: "#111827"
                background: Rectangle {
                    radius: 12
                    color: togglePasswordButton.hovered ? "#e5e7eb" : "#f3f4f6"
                    border.color: "#d1d5db"
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
                color: "#6b7280"
            }
            Text {
                text: "• от 8 до 32 символов"
                font.pixelSize: 12
                color: (passwordField.text.length >= 8 && passwordField.text.length <= 32) ? "#059669" : "#9ca3af"
            }
            Text {
                text: "• заглавная буква"
                font.pixelSize: 12
                color: /[A-Z]/.test(passwordField.text) ? "#059669" : "#9ca3af"
            }
            Text {
                text: "• строчная буква"
                font.pixelSize: 12
                color: /[a-z]/.test(passwordField.text) ? "#059669" : "#9ca3af"
            }
            Text {
                text: "• цифра"
                font.pixelSize: 12
                color: /[0-9]/.test(passwordField.text) ? "#059669" : "#9ca3af"
            }
            Text {
                text: "• без пробелов"
                font.pixelSize: 12
                color: (passwordField.text.length > 0 && !/\s/.test(passwordField.text)) ? "#059669" : "#9ca3af"
            }
        }

        Button {
            id: authButton
            text: isRegisterMode ? "Создать аккаунт" : "Войти"
            Layout.fillWidth: true
            padding: 10
            palette.buttonText: "#1f2937"
            background: Rectangle {
                radius: 12
                color: authButton.hovered ? "#e5e7eb" : "#dbeafe"
                border.color: "#93c5fd"
            }
            onClicked: {
                errorLabel.text = ""
                if (isRegisterMode) {
                    WebApi.ApiClient.register(loginField.text, passwordField.text, nameField.text, function(status, response) {
                        if (status === 201) {
                            errorLabel.color = "#059669"
                            errorLabel.text = "Регистрация успешна"
                            isRegisterMode = false
                            nameField.text = ""
                            loginField.text = ""
                            passwordField.text = ""
                        } else {
                            errorLabel.color = "#dc2626"
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
                            errorLabel.color = "#dc2626"
                            errorLabel.text = "Ошибка входа: " + (response.error || status)
                        }
                    })
                }
            }
        }

        Text {
            text: isRegisterMode ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Регистрация"
            color: "#2563eb"
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
            color: "#dc2626"
            font.pixelSize: 14
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
