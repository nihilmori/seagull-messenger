cmake_minimum_required(VERSION 3.12...3.31)
project(myservice CXX)

option(ENABLE_UNIT_TESTS "Build C++ unit tests" OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(DownloadUserver)

find_package(
    userver
    COMPONENTS core
               postgresql
    QUIET
)
if(NOT userver_FOUND)
#Tries TRY_DIR first, falls back to downloading userver from GitHub using CPM.
    download_userver(TRY_DIR third_party/userver)
endif()

userver_setup_environment()

#Common sources
include_directories(src)

add_library(
    ${PROJECT_NAME}_objs OBJECT
    src/add_user_to_chat_handler.cpp
    src/utils_handler.cpp
    src/register_handler.cpp
    src/login_handler.cpp
    src/leave_chat_handler.cpp
    src/send_message_handler.cpp
    src/get_messages_handler.cpp
    src/get_chats_handler.cpp
    src/get_user_profile_handler.cpp
    src/create_group_chat_handler.cpp
    src/remove_user_from_chat_handler.cpp
    src/search_users_handler.cpp
    src/get_chat_info_handler.cpp
)
target_link_libraries(
    ${PROJECT_NAME}_objs
    PUBLIC userver::core
           userver::postgresql
)

#The Service
add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}_objs)

#Unit Tests (optional, for future use)
if(ENABLE_UNIT_TESTS)
    file(GLOB UNITTEST_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*_test.cpp")
    if(UNITTEST_SOURCES)
        add_executable(${PROJECT_NAME}_unittest ${UNITTEST_SOURCES})
        target_link_libraries(${PROJECT_NAME}_unittest PRIVATE ${PROJECT_NAME}_objs userver::utest)
        add_google_tests(${PROJECT_NAME}_unittest)
    else()
        message(STATUS "ENABLE_UNIT_TESTS=ON, but no *_test.cpp files were found in src/")
    endif()
endif()

#Functional testing
userver_testsuite_add_simple()

#Install
include(GNUInstallDirs)

if(DEFINED ENV{PREFIX})
    message(STATUS "Set install prefix: $ENV{PREFIX}")
    file(TO_CMAKE_PATH "$ENV{PREFIX}" PREFIX_PATH)
    set(CMAKE_INSTALL_PREFIX "${PREFIX_PATH}")
endif()

file(GLOB CONFIGS_FILES ${CMAKE_CURRENT_SOURCE_DIR}/configs/*.yaml ${CMAKE_CURRENT_SOURCE_DIR}/configs/*.json)

install(
    TARGETS ${PROJECT_NAME}
    DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT ${PROJECT_NAME}
)
install(
    FILES ${CONFIGS_FILES}
    DESTINATION ${CMAKE_INSTALL_SYSCONFDIR}/${PROJECT_NAME}
    COMPONENT ${PROJECT_NAME}
)
