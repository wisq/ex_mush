# Telnet Option Negotiation

Just a quick sketch of how ExMUSH handles telnet option negotiation.

## Unicode Output

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000}}}%%

flowchart TD
    do_charset[fa:fa-server IAC DO CHARSET]

    %% The success path:
    do_charset --> will_charset([fa:fa-laptop IAC WILL CHARSET])
    will_charset --> request_utf8(fa:fa-server IAC SB CHARSET REQUEST &quot;UTF-8&quot;)
    request_utf8 --> accept_utf8([fa:fa-laptop IAC SB CHARSET ACCEPT &quot;UTF-8&quot;])
    accept_utf8 --> enable_utf8{{unicode_in: true,<br/>unicode_out: true}}

    %% The reject path:
    request_utf8 --> reject_utf8([fa:fa-laptop IAC SB CHARSET REJECT &quot;UTF-8&quot;])
    reject_utf8 --> fail

    %% The "no charset" path:
    do_charset --> wont_charset([fa:fa-laptop IAC WONT CHARSET])
    wont_charset --> fail

    %% Binary fallback:
    fail{{CHARSET negotiation failed,<br/>try binary mode instead.}}
    fail --> try_binary[fa:fa-server IAC DO TRANSMIT-BINARY<br/>IAC WILL TRANSMIT-BINARY]

    %% Successful input negotiation:
    try_binary --> will_binary([fa:fa-laptop IAC WILL TRANSMIT-BINARY])
    will_binary --> enbable_in{{unicode_in: true}}

    %% Successful output negotiation:
    try_binary --> do_binary([fa:fa-laptop IAC DO TRANSMIT-BINARY])
    do_binary --> enbable_out{{unicode_out: true}}

    %% Failed input negotiation:
    try_binary --> wont_binary([fa:fa-laptop IAC WONT TRANSMIT-BINARY])
    wont_binary --> fail_in{{No change to settings.}}

    %% Failed output negotiation:
    try_binary --> dont_binary([fa:fa-laptop IAC DONT TRANSMIT-BINARY])
    dont_binary --> fail_out{{No change to settings.}}
```

## Terminal Type

Not currently used, but will be important for auto-detecting ANSI capabilities later.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000}}}%%

flowchart TD
    do_ttype[fa:fa-server IAC DO TERMINAL-TYPE]

    %% The success path:
    do_ttype --> will_ttype([fa:fa-laptop IAC WILL TERMINAL-TYPE])
    will_ttype --> request_ttype(fa:fa-server IAC SB TERMINAL-TYPE SEND)
    request_ttype --> send_ttype([fa:fa-laptop IAC SB TERMINAL-TYPE IS &quot;ABC&quot;])
    send_ttype --> success{{Logged, ignored for now.}}

    %% The failure path:
    do_ttype --> wont_ttype([fa:fa-laptop IAC WONT TERMINAL-TYPE])
    wont_ttype --> fail{{Ignored.}}
```

## Notify About Window Size (NAWS)

Not currently used, but could be useful later in MUSHcode.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000}}}%%

flowchart TD
    do_naws[fa:fa-server IAC DO NAWS]

    %% The success path:
    do_naws --> will_naws([fa:fa-laptop IAC WILL NAWS])
    will_naws --> send_naws([fa:fa-laptop IAC SB NAWS width height])
    send_naws --> success{{Logged, ignored for now.}}

    success -->|&nbsp;size changes&nbsp;| send_naws

    %% The failure path:
    do_naws --> wont_naws([fa:fa-laptop IAC WONT NAWS])
    wont_naws --> fail{{Ignored.}}
```
