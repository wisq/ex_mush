# ExMUSH

Look, I know MUSHes are a dead medium.  That doesn't mean I can't have some fun re-imagining MUSH in Elixir.  (The two are a really good fit!)

## Reference

I'm using PennMUSH as my reference implementation.  Why?

- It has a reputation for being the most coder-friendly MUSH server out there, thanks to its useful functions and language extensions.
  - e.g. [MUSHCode.com](https://mushcode.com/) has more PennMUSH-compatible code than any other MU* variant
- It's different than the MU*s I used to hang out on (mainly TinyMUXes), without being **too** different.
  - So it's familiar, but I'm still learning new things about MUSHes in the process.
- It uses memory-based storage (periodically dumped to disk) rather than disk-based storage (on-disk DB).
  - This makes things simpler and easier to work with on my end, since flatfile is the native format and not a "you gotta ask for it" thing.
  - Also, it's how MOO did it, and MOO will always be the technological zenith of MUDs for me, so I respect that.
- It has essentially no AI code in the existing codebase.
  - I mean, the code is still _messy_ (to my eye), but at least it's _human_ messy.  Again, I can respect that.

## Project structure

*ExMUSH is very much a work-in-progress.  Everything listed here is subject to change, and depending on how long ago I updated this, it might already be out of date.*

A basic outline of important modules, subtrees, and design notes:

- `ExMUSH`: Contains some globally useful stuff, like the `~o'#123'` sigil for denoting object IDs.  Designed to be `import`ed.
- `ExMUSH.Application`: The application and root supervisor.
  - Handles some startup options, like IP and port binding.
- `ExMUSH.DB.*`: Persistent data storage (Postgres).
  - It's dirt simple because we barely use it.  We mostly just bulk-read the `objects` table on startup, read the `object_attributes` table as objects are lazy-loaded, and all writes are bulk-upserts to one table at a time.
  - The main value of using a relational DB is in the constraints that make sure everything stays sane (especially foreign keys).
- `ExMUSH.ObjectID`: Object IDs, represented as a struct.
  - This allows them to be `to_string`'d as `#123`, while being `inspect`ed as `~o'#123'`.
  - Also allows us to support the `#123:456789` format, where the second number is the object's ctime.
- `ExMUSH.World.*`: Modules under here maintain the current world state.
  - `World.Object`: Serves as both the main object structure, and an index of functions to operate on them.
    - Most functions eventually result in a call to either `World.ObjectDirectory` or a `World.ObjectServer` process.
    - ... but those functions tend to be pretty low-level and operate entirely on `ObjectID`s, so the `Object` functions are a much more friendly API.
  - `World.ObjectDirectory`: The heart of the world.
    - Reads and indexes the entire `objects` table on startup.
    - Maintains things like the player name/alias index, or the index of contents of all rooms/objects.
    - Makes extensive use of ETS, meaning pretty much all read operations can be done in the caller's process.
  - `World.ObjectDirectory.Writer`: Writes changes made by the `ObjectDirectory`.
    - All changes are cast to this module and performed asynchronously.
    - Upon receiving a change, a flush will be scheduled in 1000ms, allowing changes to be bulked together but also limiting data loss in a crash.
  - `World.ObjectServer`: Manages an object's attributes.
    - Lazily launched by `World.ObjectSupervisor` on first attribute access, and indexed by `World.ObjectRegistry`.
    - Will eventually also handle locks as well.
  - `World.Supervisor`: Master supervisor for the whole `World.*` tree.
    - Uses `strategy: :one_for_all`, meaning any crash will restart the whole world and reload from the database.  This prevents crashes from leaving the world in an inconsistent state.
    - Due to our writer strategy, we should never lose more than about one second's worth of data on a crash.
  - `World.Matching`: Handles resolving object names to objects.
    - Nearly every user command involves some matching, and this is where it all happens.
    - The `World.Matching.Opts` struct allows for extensive customisations to matching behaviour.
- `ExMUSH.Network.*`: Handles incoming connections and connects them to players.
  - `Network.Telnet`: The raw telnet connection.
    - Uses [ThousandIsland](https://github.com/mtrudel/thousand_island) to manage low-level socket concerns.
    - Currently very simple, but will eventually start doing telnet option negotiation.
  - `Network.Session`: A single user session.
    - Handles processing incoming user commands and delivering outgoing messages.
    - Launched by `Network.SessionSupervisor`, and indexed by `Network.SessionRegistry`.
    - Uses `ExMUSH.Command.Login` until the user logs in, then switches to the main command set.
    - A single player object can have more than one session connected at a time.  All player sessions will receive all output sent to the player, including the results of commands on other sessions.
- `ExMUSH.Command`: The structure used to record available user commands (after login).
    - Contains the `defcommand` macro that allows easily creating commands via annotations.
  - `Command.Table`: Loads and indexes the available commands (as an ETS).
  - `Command.Parser`: Parses lines of input and turns them into an `ExMUSH.Action` structure.
- `ExMUSH.Commands.*`: Command definitions and implementations.
  - Files in the `lib/ex_mush/commands` directory are automatically searched for `ExMUSH.Commands.*` modules.
  - These modules become the basis for the master command list.
- `ExMUSH.Action`: A single parsed command, ready to execute.
  - Action execution is handled in a separate process, launched by `Action.Supervisor`.
- `ExMUSH.ActionList`: A list of `Action` objects, meant to be run sequentially.
  - ActionList execution is handled in a separate process, launched by `ActionList.Supervisor`.
  - Waits for each `Action` to complete (but not for any asynchronous actions they might launch in turn)
  - Not actually currently used anywhere, but will become very important when MUSHcode is implemented.
- `ExMUSH.Context`: A structure representing the current command state.
  - Recursively passed down as all `Action`s (and eventually, MUSHcode) are executed.
  - This should in theory allow all MUSH commands (`Action` and `ActionList`) and code (TBD) to be fully pre-parsed (except when using `@force`), and maybe even pre-compiled, with their behaviour varying only by who and what is running the code.

## To-Do

There's still absolutely **tons** of stuff to do, but some standouts include:

- MUSHcode!
  - $-commands (and matching against them), probably just by converting them to regexes (and indexing them like ObjectDirectory does)
  - I'm hoping to be able to pre-parse all MUSHcode commands and functions — maybe even pre-compile into Elixir functions! — and just have runtime behaviour change based on the `ExMUSH.Context` they're run under
  - kinda the heart of the project, since it's the most technically complex part, and the one that benefits the most from Elixir's parallelism
- @listen patterns
  - will also need to be indexed, like $-commands
- locks
  - can probably just live on an object's `ObjectServer`, no need to index them
  - most of them only apply when we already know what object we want to interact with (via matching, $-command, or @listen), at which point other attributes will almost certainly be needed anyway
- ANSI colours / markup support.  I want to eventually support
  - basic 16-colour ANSI
  - full XTerm colour support, both 256-colour and full 24-bit RGB
  - all without actually embedding escape sequences in text until it hits the wire
- telnet options like UTF-8 (and downgrading to ASCII if needed)
  - we currently just use UTF-8 by default and accept all user input if it's considered printable, which might be unsafe 😅
