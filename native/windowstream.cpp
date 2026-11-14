#include "windowstream.h"

#include <QCoreApplication>
#include <QPointer>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <gst/video/video.h>
#include <gst/video/video-info-dma.h>
#include <gst/allocators/gstdmabuf.h>
#include <linux/dma-buf.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>

namespace {
const QString service = QStringLiteral("org.gnome.Mutter.ScreenCast");
const QString rootPath = QStringLiteral("/org/gnome/Mutter/ScreenCast");
const QString sessionInterface = service + QStringLiteral(".Session");
const QString streamInterface = service + QStringLiteral(".Stream");

QDBusMessage method(const QString &path, const QString &interface, const QString &name) {
    return QDBusMessage::createMethodCall(service, path, interface, name);
}

void stopSession(const QString &path) {
    if (!path.isEmpty())
        QDBusConnection::sessionBus().asyncCall(method(path, sessionInterface, "Stop"));
}
}

WindowStream::WindowStream(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents, true);
    gst_init(nullptr, nullptr);
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(140);
    connect(&m_debounce, &QTimer::timeout, this, &WindowStream::start);
    m_busTimer.setInterval(100);
    connect(&m_busTimer, &QTimer::timeout, this, &WindowStream::checkBus);
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(6000);
    connect(&m_timeout, &QTimer::timeout, this, [this] { fail("No frames received from Niri"); });
}

WindowStream::~WindowStream() {
    stop();
}

void WindowStream::setWindowId(int id) {
    if (m_windowId == id)
        return;
    m_windowId = id;
    emit windowIdChanged();
    restart();
}

void WindowStream::setOutput(const QString &name) {
    if (m_output == name)
        return;
    m_output = name;
    emit outputChanged();
    restart();
}

void WindowStream::setActive(bool active) {
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
    restart();
}

void WindowStream::setReady(bool ready) {
    if (m_ready == ready)
        return;
    m_ready = ready;
    emit readyChanged();
}

void WindowStream::setError(const QString &message) {
    if (m_error == message)
        return;
    m_error = message;
    emit errorChanged();
}

void WindowStream::restart() {
    stop();
    setError({});
    if (m_active && (m_windowId > 0 || !m_output.isEmpty()))
        m_debounce.start();
}

void WindowStream::stop() {
    ++m_generation;
    m_debounce.stop();
    m_busTimer.stop();
    m_timeout.stop();
    // Wait for streaming callbacks to finish before clearing their state.
    if (m_pipeline) {
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
        gst_object_unref(m_pipeline);
        m_pipeline = nullptr;
    }
    auto bus = QDBusConnection::sessionBus();
    if (!m_stream.isEmpty())
        bus.disconnect(service, m_stream, streamInterface, "PipeWireStreamAdded", this, SLOT(nodeAdded(uint)));
    if (!m_session.isEmpty())
        bus.disconnect(service, m_session, sessionInterface, "Closed", this, SLOT(sessionClosed()));
    stopSession(m_session);
    m_session.clear();
    m_stream.clear();
    {
        // Keep the last frame: QML fades the preview out on `ready` going false.
        QMutexLocker lock(&m_frameMutex);
        m_deliveryPending = false;
    }
    setReady(false);
}

void WindowStream::fail(const QString &message) {
    stop();
    setError(message);
}

void WindowStream::start() {
    if (!m_active || (m_windowId <= 0 && m_output.isEmpty()))
        return;
    const auto generation = m_generation.load();
    auto request = method(rootPath, service, "CreateSession");
    request << QVariantMap{};
    auto *call = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(request, 3000), QCoreApplication::instance());
    // The watcher also cleans up a late session after the item is destroyed.
    QPointer<WindowStream> self(this);
    connect(call, &QDBusPendingCallWatcher::finished, call, [self, generation, call] {
        QDBusPendingReply<QDBusObjectPath> reply = *call;
        call->deleteLater();
        if (!self || generation != self->m_generation) {
            if (!reply.isError())
                stopSession(reply.value().path());
            return;
        }
        if (reply.isError()) {
            self->fail(reply.error().message());
            return;
        }
        self->m_session = reply.value().path();
        auto bus = QDBusConnection::sessionBus();
        bus.connect(service, self->m_session, sessionInterface, "Closed", self, SLOT(sessionClosed()));
        // Window streams by id; otherwise the whole display by connector name.
        const bool window = self->m_windowId > 0;
        auto record = window ? method(self->m_session, sessionInterface, "RecordWindow")
                             : method(self->m_session, sessionInterface, "RecordMonitor");
        if (window) {
            record << QVariantMap{{"window-id", QVariant::fromValue<qulonglong>(self->m_windowId)},
                                  {"cursor-mode", uint(0)}};
        } else {
            record << self->m_output << QVariantMap{{"cursor-mode", uint(0)}};
        }
        auto *windowCall = new QDBusPendingCallWatcher(bus.asyncCall(record, 3000), self);
        connect(windowCall, &QDBusPendingCallWatcher::finished, self, [self, generation, windowCall] {
            QDBusPendingReply<QDBusObjectPath> result = *windowCall;
            windowCall->deleteLater();
            if (!self || generation != self->m_generation)
                return;
            if (result.isError()) {
                self->fail(result.error().message());
                return;
            }
            self->m_stream = result.value().path();
            auto bus = QDBusConnection::sessionBus();
            bus.connect(service, self->m_stream, streamInterface, "PipeWireStreamAdded", self, SLOT(nodeAdded(uint)));
            auto *startCall = new QDBusPendingCallWatcher(
                bus.asyncCall(method(self->m_session, sessionInterface, "Start"), 3000), self);
            connect(startCall, &QDBusPendingCallWatcher::finished, self, [self, generation, startCall] {
                QDBusPendingReply<> started = *startCall;
                startCall->deleteLater();
                if (self && generation == self->m_generation && started.isError())
                    self->fail(started.error().message());
            });
            self->m_timeout.start();
        });
    });
}

void WindowStream::sessionClosed() {
    fail("Window stream closed");
}

void WindowStream::nodeAdded(uint nodeId) {
    if (!m_active || m_session.isEmpty() || m_pipeline)
        return;
    // Raw frames only: no encoder, temporary images, or network server.
    // The appsink holds at most one frame; delivery to Qt is coalesced too.
    const auto pipeline = QStringLiteral(
        "pipewiresrc path=%1 do-timestamp=true ! "
        "video/x-raw(memory:DMABuf),format=DMA_DRM,drm-format={AR24,XR24} ! "  // windows: AR24, displays: XR24
        "appsink name=preview max-buffers=1 drop=true sync=false").arg(nodeId);
    GError *error = nullptr;
    m_pipeline = gst_parse_launch(pipeline.toUtf8().constData(), &error);
    if (error) {
        const QString message = QString::fromUtf8(error->message);
        g_error_free(error);
        fail(message);
        return;
    }
    if (!m_pipeline) {
        fail("Cannot create PipeWire pipeline");
        return;
    }
    auto *sink = gst_bin_get_by_name(GST_BIN(m_pipeline), "preview");
    GstAppSinkCallbacks callbacks{};
    callbacks.new_sample = &WindowStream::newSample;
    gst_app_sink_set_callbacks(GST_APP_SINK(sink), &callbacks, this, nullptr);
    gst_object_unref(sink);
    if (gst_element_set_state(m_pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        fail("Cannot start PipeWire pipeline");
        return;
    }
    m_busTimer.start();
}

GstFlowReturn WindowStream::newSample(GstAppSink *sink, gpointer data) {
    auto *self = static_cast<WindowStream *>(data);
    GstSample *sample = gst_app_sink_pull_sample(sink);
    if (!sample)
        return GST_FLOW_EOS;
    GstVideoInfo info{};
    GstVideoInfoDmaDrm dmaInfo{};
    GstBuffer *buffer = gst_sample_get_buffer(sample);
    GstMemory *memory = gst_buffer_peek_memory(buffer, 0);
    const auto *meta = gst_buffer_get_video_meta(buffer);
    const bool valid = gst_video_info_dma_drm_from_caps(&dmaInfo, gst_sample_get_caps(sample)) &&
                       gst_video_info_dma_drm_to_video_info(&dmaInfo, &info) &&
                       dmaInfo.drm_modifier == 0 && gst_is_dmabuf_memory(memory);
    // Niri advertises maxsize=1 for DMA-BUFs. Generic GstVideoFrame mapping would
    // map just that byte. Map the actual linear plane, validating against fd size.
    const int stride = meta ? meta->stride[0] : info.stride[0];
    gsize memoryOffset = 0;
    gst_memory_get_sizes(memory, &memoryOffset, nullptr);
    const gsize offset = memoryOffset + (meta ? meta->offset[0] : 0);
    const gsize length = offset + gsize(stride) * info.height;
    const int fd = valid ? gst_dmabuf_memory_get_fd(memory) : -1;
    struct stat statbuf{};
    if (valid && stride >= int(info.width * 4) && fstat(fd, &statbuf) == 0 &&
        length > 0 && length <= gsize(statbuf.st_size)) {
        void *mapping = mmap(nullptr, length, PROT_READ, MAP_SHARED, fd, 0);
        if (mapping == MAP_FAILED) {
            gst_sample_unref(sample);
            return GST_FLOW_ERROR;
        }
        struct dma_buf_sync sync{DMA_BUF_SYNC_START | DMA_BUF_SYNC_READ};
        ioctl(fd, DMA_BUF_IOCTL_SYNC, &sync);
        // Windows carry alpha (AR24); displays are opaque (XR24) and must not be read as transparent.
        const bool hasAlpha = GST_VIDEO_INFO_HAS_ALPHA(&info);
        const auto format = hasAlpha ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32;
        QImage image(static_cast<const uchar *>(mapping) + offset,
                     info.width, info.height, stride, format);
        QImage copy = image.copy();
        if (!hasAlpha) {
            // XR24's padding byte is undefined (niri sends 0x00), but Qt treats RGB32 as
            // 0xffRRGGBB. Left as-is, it is drawn as zero alpha and the overlay turns
            // see-through. Force it opaque.
            for (int y = 0; y < copy.height(); ++y) {
                auto *row = reinterpret_cast<quint32 *>(copy.scanLine(y));
                for (int x = 0; x < copy.width(); ++x)
                    row[x] |= 0xff000000u;
            }
        }
        {
            QMutexLocker lock(&self->m_frameMutex);
            self->m_frame = std::move(copy);
            if (!self->m_deliveryPending) {
                self->m_deliveryPending = true;
                const auto generation = self->m_generation.load();
                QMetaObject::invokeMethod(self, [self, generation] {
                    if (generation != self->m_generation)
                        return;
                    {
                        QMutexLocker lock(&self->m_frameMutex);
                        self->m_deliveryPending = false;
                    }
                    self->m_timeout.stop();
                    QSize size;
                    {
                        QMutexLocker lock(&self->m_frameMutex);
                        size = self->m_frame.size();
                    }
                    if (size != self->m_sourceSize) {
                        self->m_sourceSize = size;
                        emit self->sourceSizeChanged();
                    }
                    self->setReady(true);
                    ++self->m_frameCount;
                    emit self->frameCountChanged();
                    self->update();
                }, Qt::QueuedConnection);
            }
        }
        sync.flags = DMA_BUF_SYNC_END | DMA_BUF_SYNC_READ;
        ioctl(fd, DMA_BUF_IOCTL_SYNC, &sync);
        munmap(mapping, length);
    }
    gst_sample_unref(sample);
    return GST_FLOW_OK;
}

void WindowStream::checkBus() {
    if (!m_pipeline)
        return;
    GstBus *bus = gst_element_get_bus(m_pipeline);
    GstMessage *message = gst_bus_pop_filtered(bus, GstMessageType(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));
    gst_object_unref(bus);
    if (!message)
        return;
    QString text = "Window stream ended";
    if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
        GError *error = nullptr;
        gchar *debug = nullptr;
        gst_message_parse_error(message, &error, &debug);
        text = QString::fromUtf8(error->message);
        g_error_free(error);
        g_free(debug);
    }
    gst_message_unref(message);
    fail(text);
}

QSGNode *WindowStream::updatePaintNode(QSGNode *old, UpdatePaintNodeData *) {
    QImage image;
    {
        QMutexLocker lock(&m_frameMutex);
        image = m_frame;
    }
    if (image.isNull() || !window()) {
        delete old;
        return nullptr;
    }
    auto *node = static_cast<QSGSimpleTextureNode *>(old);
    if (!node) {
        node = new QSGSimpleTextureNode;
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
    }
    // The node owns its texture and deletes the previous one itself.
    node->setTexture(window()->createTextureFromImage(image));
    const QSizeF fitted = QSizeF(image.size()).scaled(boundingRect().size(), Qt::KeepAspectRatio);
    node->setRect(QRectF(QPointF((width() - fitted.width()) / 2, (height() - fitted.height()) / 2), fitted));
    return node;
}
