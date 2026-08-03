# Telnet Option Negotiation

Just a quick sketch of how ExMUSH handles telnet option negotiation.

### Legend

```mermaid
flowchart LR
    key{ User <br/> keypress } --> client([ Message from client ])
    server[[ Message from server ]] --> action{{ Server-side action }}
    linkStyle default display:none;
```

## Unicode Output

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000 }} }%%

flowchart TD
    do_charset[[ IAC DO CHARSET ]]

    %% The success path:
    do_charset --> will_charset([ IAC WILL CHARSET ])
    will_charset --> request_utf8[[ IAC SB CHARSET REQUEST &quot;UTF-8&quot; ]]
    request_utf8 --> accept_utf8([ IAC SB CHARSET ACCEPT &quot;UTF-8&quot; ])
    accept_utf8 --> enable_utf8{{ unicode_in: true,<br/>unicode_out: true }}

    %% The reject path:
    request_utf8 --> reject_utf8([ IAC SB CHARSET REJECT &quot;UTF-8&quot; ])
    reject_utf8 --> fail

    %% The "no charset" path:
    do_charset --> wont_charset([ IAC WONT CHARSET ])
    wont_charset --> fail

    %% Binary fallback:
    fail{{ CHARSET negotiation failed,<br/>try binary mode instead. }}
    fail --> try_binary[[ IAC DO TRANSMIT-BINARY<br/>IAC WILL TRANSMIT-BINARY ]]

    %% Successful input negotiation:
    try_binary --> will_binary([ IAC WILL TRANSMIT-BINARY ])
    will_binary --> enbable_in{{ unicode_in: true }}

    %% Successful output negotiation:
    try_binary --> do_binary([ IAC DO TRANSMIT-BINARY ])
    do_binary --> enbable_out{{ unicode_out: true }}

    %% Failed input negotiation:
    try_binary --> wont_binary([ IAC WONT TRANSMIT-BINARY ])
    wont_binary --> fail_in{{ No change to settings. }}

    %% Failed output negotiation:
    try_binary --> dont_binary([ IAC DONT TRANSMIT-BINARY ])
    dont_binary --> fail_out{{ No change to settings. }}
```

## Terminal Type

Not currently used, but will be important for auto-detecting ANSI capabilities later.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000 }} }%%

flowchart TD
    do_ttype[[ IAC DO TERMINAL-TYPE ]]

    %% The success path:
    do_ttype --> will_ttype([ IAC WILL TERMINAL-TYPE ])
    will_ttype --> request_ttype[[ IAC SB TERMINAL-TYPE SEND ]]
    request_ttype --> send_ttype([ IAC SB TERMINAL-TYPE IS &quot;ABC&quot; ])
    send_ttype --> success{{ Logged, ignored for now. }}

    %% The failure path:
    do_ttype --> wont_ttype([ IAC WONT TERMINAL-TYPE ])
    wont_ttype --> fail{{ Ignored. }}
```

## Notify About Window Size (NAWS)

Not currently used, but could be useful later in MUSHcode.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000 }} }%%

flowchart TD
    do_naws[[ IAC DO NAWS ]]

    %% The success path:
    do_naws --> will_naws([ IAC WILL NAWS ])
    will_naws --> send_naws([ IAC SB NAWS width height ])
    send_naws --> success{{ Logged, ignored for now. }}

    success -->|&nbsp;size changes&nbsp;| send_naws

    %% The failure path:
    do_naws --> wont_naws([ IAC WONT NAWS ])
    wont_naws --> fail{{ Ignored. }}
```

## Other


```mermaid
%%{init: {"flowchart": {"wrappingWidth": 10000 }} }%%

flowchart LR
    invis1 ---> iac([ IAC IAC ]) ---> literal{{ Treated as IAC character <br/> in data stream }}
    invis1 ---> noop([ IAC NO-OP ]) ---> ignore{{ Ignored }}

    style invis1 display:none, font-size: 0px;
    linkStyle 0 display:none;
    linkStyle 2 display:none;

    ctrl_c{ctrl-C} ---> interrupt([ IAC INTERRUPT-PROCESS <br/> IAC DO TIMING-MARK ]) ---> wont_timing
    ctrl_bk{ctrl-\} ---> break([IAC BREAK <br/> IAC DO TIMING-MARK ]) ---> wont_timing
    ctrl_z{ctrl-Z} ---> suspend([ IAC SUSPEND <br/> IAC DO TIMING-MARK ]) ---> wont_timing
    wont_timing[[ #40;command ignored#41; <br/> IAC WONT TIMING-MARK <br/> #40;not logged#41; ]]

    ctrl_t{ctrl-T} ---> ping([ IAC ARE-YOU-THERE ]) ---> pong[[ *** Server is up *** ]]

    invis2 ---> do([ IAC DO x ]) ---> wont[[ IAC WONT x <br/> #40;logged#41; ]]
    invis2 ---> will([ IAC WILL x ]) ---> dont[[ IAC DONT x <br/> #40;logged#41;]]
    style invis2 display:none, font-size: 0px;
    linkStyle 12 display:none;
    linkStyle 14 display:none;
```
