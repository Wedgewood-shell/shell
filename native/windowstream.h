#pragma once

#include <atomic>
#include <QImage>
#include <QMutex>
#include <QQuickItem>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <gst/app/gstappsink.h>

// One compositor stream, no screenshot actions, file cache, or clipboard access.
class WindowStream : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(int windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(quint64 frameCount READ frameCount NOTIFY frameCountChanged)
    // Pixel size of the latest frame; kept after stopping so a fade-out still has content.
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)

public:
    explicit WindowStream(QQuickItem *parent = nullptr);
    ~WindowStream() override;
    int windowId() const { return m_windowId; }
    bool active() const { return m_active; }
    bool ready() const { return m_ready; }
    QString error() const { return m_error; }
    quint64 frameCount() const { return m_frameCount; }
    QSize sourceSize() const { return m_sourceSize; }
    void setWindowId(int id);
    void setActive(bool active);

signals:
    void windowIdChanged();
    void activeChanged();
    void readyChanged();
    void errorChanged();
    void frameCountChanged();
    void sourceSizeChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;

private slots:
    void nodeAdded(uint nodeId);
    void sessionClosed();

private:
    void restart();
    void start();
    void stop();
    void fail(const QString &message);
    void setError(const QString &message);
    void setReady(bool ready);
    void checkBus();
    static GstFlowReturn newSample(GstAppSink *sink, gpointer data);

    int m_windowId = -1;
    bool m_active = false;
    bool m_ready = false;
    QString m_error;
    std::atomic<quint64> m_generation{0};
    quint64 m_frameCount = 0;
    QString m_session;
    QString m_stream;
    GstElement *m_pipeline = nullptr;
    QTimer m_debounce;
    QTimer m_busTimer;
    QTimer m_timeout;
    QMutex m_frameMutex;
    QImage m_frame;
    QSize m_sourceSize;
    bool m_deliveryPending = false;
};
