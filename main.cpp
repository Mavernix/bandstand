// theme and config arrive as the json file in DESKTOP_SHELL_SETTINGS (session/make_shell_config.py)

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include <cstdio>
#include <cstdlib>

#include "library.hpp"
#include "music-client.hpp"
#include "play-queue.hpp"

static QString expanded(const QString& path)
{
    if (path == QLatin1String("~"))
    {
        return QDir::homePath();
    }

    return path.startsWith(QLatin1String("~/")) ? QDir::homePath() + path.mid(1) : path;
}

static QVariantMap read_settings()
{
    const QString path = qEnvironmentVariable("DESKTOP_SHELL_SETTINGS");
    if (path.isEmpty())
    {
        std::fprintf(stderr, "bandstand: DESKTOP_SHELL_SETTINGS is not set. "
            "Start it from a Mavernix session, "
            "which sets it.\n");
        std::exit(1);
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
    {
        std::fprintf(stderr, "bandstand: cannot read the settings file %s\n",
            qPrintable(path));
        std::exit(1);
    }

    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}

int main(int argc, char **argv)
{
    QGuiApplication application(argc, argv);
    // the dock and panel match windows to apps by this
    QGuiApplication::setDesktopFileName(QStringLiteral("bandstand"));

    const QVariantMap settings = read_settings();

    const QVariantMap music_config = settings.value(QStringLiteral("config")).toMap()
        .value(QStringLiteral("music")).toMap();
    const QString folder = expanded(music_config.value(QStringLiteral("folder"),
        QStringLiteral("~/.local/share/bandstand")).toString());

    MusicClient client(QStringLiteral(HELPER_DIRECTORY "/music_helper.py"));
    PlayQueue queue;
    Library library(folder);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("settings"), settings);
    engine.rootContext()->setContextProperty(QStringLiteral("client"), &client);
    engine.rootContext()->setContextProperty(QStringLiteral("queue"), &queue);
    engine.rootContext()->setContextProperty(QStringLiteral("library"), &library);
    engine.load(QStringLiteral(QML_DIRECTORY "/Main.qml"));
    if (engine.rootObjects().isEmpty())
    {
        std::fprintf(stderr, "bandstand: could not load %s/Main.qml (messages above)\n",
            QML_DIRECTORY);
        return 1;
    }

    return application.exec();
}
