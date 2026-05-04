import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ApiClient.js" as WebApi

Rectangle {
    id: loginRoot
    anchors.fill: parent
    color: "#f0f2f5"

    property bool isRegisterMode: false
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
        }

        TextField {
            id: loginField
            placeholderText: "Логин"
            Layout.fillWidth: true
            selectByMouse: true
        }

        TextField {
            id: passwordField
            placeholderText: "Пароль"
            echoMode: TextInput.Password
            Layout.fillWidth: true
            selectByMouse: true
        }

        Button {
            text: isRegisterMode ? "Создать аккаунт" : "Войти"
            Layout.fillWidth: true
            onClicked: {
                errorLabel.text = ""
                if (isRegisterMode) {
                    WebApi.ApiClient.register(loginField.text, passwordField.text, nameField.text, function(status, response) {
                        if (status === 201) {
                            errorLabel.color = "#059669"
                            errorLabel.text = "Регистрация успешна"
                            isRegisterMode = false
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
