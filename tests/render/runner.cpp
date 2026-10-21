#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickImageProvider>
#include <QtQuickTest/quicktest.h>

// Observe the real QML Image request boundary. Decode only the existing benign
// fixtures, never a path from a test input. This provider is test-only.
class FixtureProvider : public QQuickImageProvider {
public:
    FixtureProvider(QQmlPropertyMap *requests, const QString &provider)
        : QQuickImageProvider(Pixmap), requests(requests), provider(provider) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
        requests->insert("last", provider + "/" + id);
        requests->insert("count", requests->value("count").toInt() + 1);
        const auto name = id.section('?', 0, 0);
        const auto filename = name == "badge-symbolic" ? "badge-symbolic" : "badge.svg";
        QPixmap pixmap(qEnvironmentVariable("TILELANE_ICON_FIXTURES") + "/" + filename);
        if (requested.isValid()) pixmap = pixmap.scaled(requested, Qt::KeepAspectRatio);
        if (size) *size = pixmap.size();
        return pixmap;
    }
private:
    QQmlPropertyMap *requests;
    QString provider;
};

class Setup : public QObject {
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        auto *requests = QQmlPropertyMap::create(engine);
        requests->insert("count", 0);
        requests->insert("last", "");
        engine->rootContext()->setContextProperty("iconRequests", requests);
        engine->addImageProvider("icon", new FixtureProvider(requests, "icon"));
        engine->addImageProvider("qsimage", new FixtureProvider(requests, "qsimage"));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(tray, Setup)
#include "runner.moc"
