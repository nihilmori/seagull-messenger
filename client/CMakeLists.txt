cmake_minimum_required(VERSION 3.16)

project(SeagullClient VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml QuickControls2)

qt_standard_project_setup()

qt_add_executable(appSeagullClient
    main.cpp
)

qt_add_qml_module(appSeagullClient
    URI SeagullClient
    VERSION 1.0
    QML_FILES
        Main.qml
        LoginScreen.qml
        TopBar.qml
        ChatSidebar.qml
        ChatHeaderCard.qml
        MessageList.qml
        MessageComposer.qml
	WallScreen.qml
	WallPostList.qml
	WallPostComposer.qml
	WallPost.qml
    RESOURCES
        ApiClient.js
)

target_link_libraries(appSeagullClient
    PRIVATE Qt6::Quick
            Qt6::Qml
            Qt6::QuickControls2
)

install(TARGETS appSeagullClient
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
