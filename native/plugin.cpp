#include "windowstream.h"
#include <QQmlExtensionPlugin>
#include <qqml.h>

class NiriCapturePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        qmlRegisterType<WindowStream>(uri, 1, 0, "WindowStream");
    }
};

#include "plugin.moc"
