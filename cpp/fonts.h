// The kit's type, made known to the app before its first window: every
// font in the module's `assets/fonts/` (TrueType and OpenType), the faces a
// world's app carries itself (its title face, handed over by `addFont`),
// and which face draws a character a face lacks, so Japanese in the sans is
// set in Zen Kaku Gothic New, and a kanji a title face was cut without in
// a face of its kind. `src/fonts.rs` calls it.

#pragma once

#include <cstdint>

#include <QtCore/QByteArray>
#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtGui/QFont>
#include <QtGui/QFontDatabase>

#include "rust/cxx.h"

namespace sol {

inline void
loadFonts()
{
  QDirIterator files(QStringLiteral(":/qt/qml/Sol/Design/assets/fonts"),
                     { QStringLiteral("*.ttf"), QStringLiteral("*.otf") },
                     QDir::Files);
  while (files.hasNext()) {
    QFontDatabase::addApplicationFont(files.next());
  }
  // Fonts named in SOL_FONTS (files joined by ':'): the gallery shows the
  // worlds' own title faces with it, which the kit doesn't carry.
  const QString extra = qEnvironmentVariable("SOL_FONTS");
  for (const QString& file : extra.split(QLatin1Char(':'), Qt::SkipEmptyParts)) {
    QFontDatabase::addApplicationFont(file);
  }
  const QString jpSans = QStringLiteral("Zen Kaku Gothic New");
  QFont::insertSubstitution(QStringLiteral("Outfit"), jpSans);
  QFont::insertSubstitution(QStringLiteral("Chakra Petch"), jpSans);
  QFont::insertSubstitution(QStringLiteral("JetBrains Mono"), jpSans);
  // The title faces: the sans ones fall back on the sans, the brush on the mincho.
  QFont::insertSubstitution(QStringLiteral("Corporate Logo ver3"), jpSans);
  QFont::insertSubstitution(QStringLiteral("Makinas"), jpSans);
  QFont::insertSubstitution(QStringLiteral("Keifont"), jpSans);
  QFont::insertSubstitutions(
    QStringLiteral("Yuji Syuku"),
    { QStringLiteral("Shippori Mincho"), QStringLiteral("Noto Serif CJK JP") });
}

inline void
addFont(rust::Slice<const std::uint8_t> data)
{
  QFontDatabase::addApplicationFontFromData(
    QByteArray(reinterpret_cast<const char*>(data.data()),
               static_cast<qsizetype>(data.size())));
}

} // namespace sol
