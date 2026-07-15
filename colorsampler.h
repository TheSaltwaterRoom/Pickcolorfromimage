#ifndef COLORSAMPLER_H
#define COLORSAMPLER_H

#include <QImage>
#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class ColorSampler : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int imageWidth READ imageWidth NOTIFY imageChanged)
    Q_PROPERTY(int imageHeight READ imageHeight NOTIFY imageChanged)

public:
    explicit ColorSampler(QObject *parent = nullptr);

    int imageWidth() const;
    int imageHeight() const;

    Q_INVOKABLE bool loadImage(const QUrl &url);
    Q_INVOKABLE QVariantMap colorAt(int x, int y) const;

signals:
    void imageChanged();

private:
    QImage m_image;
};

#endif // COLORSAMPLER_H
