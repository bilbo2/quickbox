message(including plugin $$PWD)

PLUGIN_NAME = Competitors

include ( ../quickeventqmlplugin.pri )

QT += widgets sql

INCLUDEPATH += \
$$PWD/../../../../lib/include

LIBS += -lquickevent

include (src/src.pri)

RESOURCES += \
#    $${PLUGIN_NAME}.qrc \

OTHER_FILES += \
	$$PWD/qml/reports/* \

DISTFILES += \
    qml/CompetitorsModel.qml
