pragma Singleton
import QtQuick

/*
    In-app notices: short messages at the top edge. They fade in and leave
    after six seconds; the time stops while the pointer is on one. The
    window shows them; anything can post one.

        Notices.show({ world: "terra", title: "Not saved", body: why, tone: "error" })
        Notices.show({ title: "Changed on another device too", action: "See both", run: () => win.keptAside.open() })
        Notices.failed("neptune", "Couldn’t play that", why)   // says it as a person would, the raw words under Details

    A failure is said as a person would, in the world's voice, Japanese
    then English: `lines` turns known errors into a line (the kit's own
    for sound, the network, keys, the disk; a world adds its own first with
    `Notices.speak([{ pattern, jp, line }])`), and the raw words wait
    behind "Details". A short plain reason is shown as it is.
*/
QtObject {
    id: notices

    /** How long a notice stays, unless held. */
    readonly property int linger: 6000
    /** Each row: key, world, title, body, tone, action (a button's label, or ""), jp (said before the body, or ""), detail (behind "Details", or ""). */
    property ListModel list: ListModel {}
    property int next: 1
    /** What each notice's button does, by key. */
    property var runs: ({})

    /** Posts a notice; `action` and `run` add a button that runs it and closes the notice; `jp` is said before the
        body (the world's voice), `detail` waits behind "Details" (the raw words of a failure). */
    function show(notice) {
        const key = next++
        if (notice.action && notice.run) runs[key] = notice.run
        list.append({ key: key, world: notice.world || "sol", title: notice.title || "", body: notice.body || "", tone: notice.tone || "info", action: notice.action && notice.run ? notice.action : "",
                      jp: notice.jp || "", detail: notice.detail || "" })
        while (list.count > 4) dismiss(list.get(0).key)
        return key
    }

    function dismiss(key) {
        delete runs[key]
        for (let i = 0; i < list.count; i++) if (list.get(i).key === key) { list.remove(i); return }
    }

    /** Presses a notice's button: runs what it does, and the notice goes. */
    function act(key) {
        const run = runs[key]
        dismiss(key)
        if (run) run()
    }

    /**
        A failure as a notice: titled for what didn't happen, the reason as
        its body, said as a person would when it is a known one (`lineFor`),
        the raw words behind "Details" when they are a machine's.
    */
    function failed(world, title, why) {
        const raw = String(why)
        const said = lineFor(raw)
        if (said) return show({ world: world, title: title, jp: said.jp, body: said.line, detail: raw, tone: "error" })
        if (technical(raw)) return show({ world: world, title: title, jp: "うまくいかなかった…", body: "Something went wrong on the way.", detail: raw, tone: "error" })
        return show({ world: world, title: title, body: raw, tone: "error" })
    }

    /**
        Known failures and how they are said, `{ pattern, jp, line }`, the
        first that matches the raw words: a world's own (`speak`) before the
        kit's. Keep each line short, plain and kind: what happened and what
        to do.
    */
    property var lines: []
    /** Adds a world's own lines before the others, in its navigator's voice. */
    function speak(more) { lines = more.concat(lines) }
    readonly property var kitLines: [
        { pattern: /snd_pcm|alsa|no (audio|sound|output) device|audio (output|device)|cpal|pulseaudio|pipewire/i, jp: "音が出ない…スピーカーを確かめて。", line: "No sound device. Check your speakers." },
        { pattern: /timed? ?out|deadline/i, jp: "返事がない…少し待ってみて。", line: "No answer in time. Try again in a moment." },
        { pattern: /connection refused|couldn.t connect|error sending request|dns|failed to lookup|network is unreachable|no route to host|connection reset/i, jp: "つながらない…", line: "Can’t reach it. Check the connection." },
        { pattern: /\b401\b|\b403\b|unauthori[sz]ed|forbidden|wrong (password|key)|invalid (token|key|credentials)/i, jp: "鍵が合わないみたい。", line: "The key or password wasn’t accepted." },
        { pattern: /\b5\d\d\b|internal server error|bad gateway|service unavailable/i, jp: "向こうの調子が悪いみたい。", line: "The other side is having trouble. Try again later." },
        { pattern: /no space left|read-only file system|permission denied|disk full/i, jp: "ここに書けない…", line: "Couldn’t write it on this computer." }
    ]
    /** How `raw` is said: `{ jp, line }` of the first line that matches it, or null. */
    function lineFor(raw) {
        for (const l of lines.concat(kitLines)) if (l.pattern.test(raw)) return { jp: l.jp, line: l.line }
        return null
    }
    /** Whether `raw` is a machine's words (a chain of causes, codes, paths) rather than a short plain reason. */
    function technical(raw) {
        return raw.length > 120 || /::|os error|errno|0x[0-9a-f]{4,}|[{}<>]|\.rs\b|panicked|\bat line\b|[a-z]+_[a-z_]+\(|: [a-z ]*error\b/i.test(raw)
    }
}
