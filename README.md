<p align="center"><img src="docs/icon.png" width="128" alt=""></p>

# HP Launcher

Play the PC versions of *Harry Potter and the Sorcerer's Stone*, *Chamber of Secrets* and *Prisoner of
Azkaban* on a Mac, from your own game files.

![HP Launcher](docs/screenshot.png)

## Three ways to play

- **Original**: the Windows game as it shipped, run through [CrossOver](https://www.codeweavers.com/crossover)
  with [dgVoodoo 2](http://dege.freeweb.hu/dgVoodoo2/) for the graphics.
- **Remastered** (beta): the game running natively on the Mac. See below.
- **Custom**: an engine you choose, such as [OpenHP1](https://github.com/SplittyDev/openhp1) for
  *Sorcerer's Stone*, set up for you.

The games aren't included. Choose your installed copy, a ZIP of it or a disc image. The app makes its own
copy and never changes yours.

## The remasters (beta)

Each remaster replaces the game's original Windows engine with one built for the Mac, and plays the
original levels, art, sound and scripts on it. Nothing runs through Windows, so there's no CrossOver or
graphics add-on to set up.

- **Chamber of Secrets** runs on [SurrealEngine](https://github.com/dpjudas/SurrealEngine), an open-source
  recreation of Unreal Engine 1, extended for this game. It plays any PC copy, including discs that still
  have their copy protection, and controllers work as soon as you connect one.
- **Prisoner of Azkaban** has its own engine, written from scratch in C++ and Metal. It needs the North
  American PC release and uses the keyboard and mouse for now.

Both play the whole story, start to finish. They're in beta, so some details may still differ from the
originals. They're developed separately and ship inside the app; a build of this repository alone offers
Original and Custom.

## Requirements

- An Apple silicon Mac with macOS 26
- Your own PC copy of the game
- For Original: CrossOver 26 or later (CrossOver Preview is much faster) and dgVoodoo 2.79.3, which Setup
  links to

## Building

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
tools/test.sh     # unit tests
tools/build.sh    # build/HP Launcher.app
```

The build signs with a Developer ID certificate. Set `DEVELOPMENT_TEAM` in `project.yml` to your own.

## Layout

| Folder | |
| --- | --- |
| `App/Sources/Import` | turning a folder, ZIP or disc image into the app's copy |
| `App/Sources/Original` | running the Windows games under CrossOver |
| `App/Sources/Remastered` | starting the native engines |
| `App/Sources/Custom` | running an engine the player chooses |
| `App/Sources/UI` | the window, setup, settings and the night scenes |

Design notes are in [docs/Design.md](docs/Design.md).

## License

MIT, see [LICENSE](LICENSE). The license covers this code only, not the games or the Remastered engines.

HP Launcher is an independent project, not affiliated with or endorsed by Warner Bros., Electronic Arts or
CodeWeavers. Harry Potter names are trademarks of their owners.
