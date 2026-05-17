#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QDir>

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    
    QQuickStyle::setStyle("Basic");
    
    QQmlApplicationEngine engine;
    
    engine.addImportPath(QDir::currentPath());
    
    engine.load(QUrl::fromLocalFile("Main.qml"));
    
    return app.exec();
}
