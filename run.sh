#!/bin/sh

#_build/dev/rel/laveno_uci_app/bin/laveno_uci_app stop
#_build/dev/rel/laveno_uci_app/bin/laveno_uci_app start
RELEASE_COOKIE=secreto _build/dev/rel/laveno_uci_app/bin/laveno_uci_app rpc "Laveno.UCI.main([])"
