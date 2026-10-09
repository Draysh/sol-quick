pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Particles

/*
    A burst of sparks in the world's colour, for a moment that deserves
    one: a review finished, a streak kept, a set done. Put it where the
    sparks should come from and call `burst()`; it costs nothing while
    quiet.

        Spark { id: spark; anchors.centerIn: card }   …   spark.burst()
*/
Item {
    id: spark

    property color color: Theme.world
    property int count: 48

    width: 1; height: 1

    function burst() { system.running = true; emitter.burst(count) }

    ParticleSystem {
        id: system
        running: false
        onEmptyChanged: if (empty) running = false
        Emitter {
            id: emitter
            anchors.centerIn: parent
            enabled: false
            lifeSpan: 900
            lifeSpanVariation: 400
            size: 4
            sizeVariation: 3
            velocity: AngleDirection { angleVariation: 180; magnitude: 160; magnitudeVariation: 90 }
            acceleration: PointDirection { y: 140 }
        }
        ItemParticle {
            delegate: Rectangle {
                width: 4; height: 4; radius: 2
                color: spark.color
                opacity: 0.9
            }
        }
    }
}
