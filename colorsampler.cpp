#include "colorsampler.h"

#include <QColor>

ColorSampler::ColorSampler(QObject *parent)
    : QObject(parent)
{
}

int ColorSampler::imageWidth() const
{
    return m_image.width();
}

int ColorSampler::imageHeight() const
{
    return m_image.height();
}

bool ColorSampler::loadImage(const QUrl &url)
{
    QImage image;
    const bool loaded = url.isLocalFile()
                        && image.load(url.toLocalFile(), "BMP");

    if (!loaded) {
        m_image = QImage();
        emit imageChanged();
        return false;
    }

    m_image = image;
    emit imageChanged();
    return true;
}

QVariantMap ColorSampler::colorAt(int x, int y) const
{
    if (!m_image.valid(x, y))
        return {{QStringLiteral("valid"), false}};

    const QColor color = m_image.pixelColor(x, y);
    return {
        {QStringLiteral("valid"), true},
        {QStringLiteral("r"), color.red()},
        {QStringLiteral("g"), color.green()},
        {QStringLiteral("b"), color.blue()},
        {QStringLiteral("hex"), color.name(QColor::HexRgb).toUpper()}
    };
}
