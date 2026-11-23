<p align="center"><img src="docs/icon.png" width="128" alt=""></p>

# HP Launcher

A Mac app for playing the PC versions of *Harry Potter and the Sorcerer's Stone*, *Chamber of Secrets*
and *Prisoner of Azkaban* from your own game files.

![HP Launcher](docs/screenshot.png)

Each game can be played two ways:

- **Original** runs the Windows game as it shipped, through [CrossOver](https://www.codeweavers.com/crossover)
  and [dgVoodoo 2](http://dege.freeweb.hu/dgVoodoo2/).
- **Remastered** runs a native engine on the same files. The engines are separate projects and aren't
  in this repository.

The games aren't included. Choose your installed copy, a ZIP of it or a disc image, and the app makes
its own copy. Your files are only read.

## Requirements

- An Apple silicon Mac with macOS 26
- Your own PC copy of the game
- For Original: CrossOver 26 or later (CrossOver Preview is much faster) and the dgVoodoo 2.79.3 ZIP

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
| `App/Sources/UI` | the window, setup, settings and the night scenes |

Design notes are in [docs/Design.md](docs/Design.md).

## License

MIT, see [LICENSE](LICENSE). The license covers this code only, not the games or the Remastered engines.

HP Launcher is an independent project, not affiliated with or endorsed by Warner Bros., Electronic Arts
or CodeWeavers. Harry Potter names are trademarks of their owners.
