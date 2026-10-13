// The kit's type, made known to the app before its first window: every
// font in the module's `assets/fonts/` (TrueType), and which face
// draws a character a face lacks, so Japanese in the sans is set in Zen
// Kaku Gothic New, and a kanji the title serif was cut without in the
// system's Noto Serif CJK. `src/fonts.rs` calls it.

#pragma once

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QString>
#include <QtGui/QFont>
#include <QtGui/QFontDatabase>

namespace sol {

inline void
loadFonts()
{
  QDirIterator files(QStringLiteral(":/qt/qml/Sol/Design/assets/fonts"),
                     { QStringLiteral("*.ttf") },
                     QDir::Files);
  while (files.hasNext()) {
    QFontDatabase::addApplicationFont(files.next());
  }
  const QString jpSans = QStringLiteral("Zen Kaku Gothic New");
  QFont::insertSubstitution(QStringLiteral("Outfit"), jpSans);
  QFont::insertSubstitution(QStringLiteral("Chakra Petch"), jpSans);
  QFont::insertSubstitution(QStringLiteral("JetBrains Mono"), jpSans);
  QFont::insertSubstitution(QStringLiteral("Shippori Mincho B1"),
                            QStringLiteral("Noto Serif CJK JP"));
}

} // namespace sol
