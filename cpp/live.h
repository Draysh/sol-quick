// Screens without a build: maps a compiled QML module's files
// (`qrc:/qt/qml/Sol/Design/qml/Button.qml`) to the same files in a checkout
// (`<kit>/qml/Button.qml`), so a preview shows an edited screen when it
// starts again. A file missing from the checkout stays the compiled one.
// `src/live.rs` says when it is on.

#pragma once

#include <QtCore/QFileInfo>
#include <QtCore/QList>
#include <QtCore/QPair>
#include <QtCore/QString>
#include <QtCore/QUrl>
#include <QtQml/QQmlAbstractUrlInterceptor>
#include <QtQml/QQmlApplicationEngine>

#include "rust/cxx.h"

namespace sol {

class ReadFromDisk final : public QQmlAbstractUrlInterceptor
{
public:
  // Each module's folder in the resources, and the checkout's folder for it.
  QList<QPair<QString, QString>> folders;

  QUrl intercept(const QUrl& url, DataType type) override
  {
    if (type != QmlFile && type != JavaScriptFile) {
      return url;
    }
    const QString name = url.toString();
    for (const auto& folder : folders) {
      if (name.startsWith(folder.first)) {
        const QString path = folder.second + name.mid(folder.first.size());
        if (QFileInfo::exists(path)) {
          return QUrl::fromLocalFile(path);
        }
      }
    }
    return url;
  }
};

// Reads the QML under `from` (a module's folder in the resources) from the
// folder `to` instead, for every component `engine` loads from now on.
inline void
readFromDisk(QQmlApplicationEngine& engine, rust::Str from, rust::Str to)
{
  static ReadFromDisk interceptor;
  interceptor.folders.append(
    { QString::fromUtf8(from.data(), static_cast<qsizetype>(from.size())),
      QString::fromUtf8(to.data(), static_cast<qsizetype>(to.size())) });
  if (!engine.urlInterceptors().contains(&interceptor)) {
    engine.addUrlInterceptor(&interceptor);
  }
}

} // namespace sol
