##################################
## Script-Name:     macht-sinn  ##
## Type:            Script      ##
## Creator:         Crosser     ##
## License:         GPLv3       ##
##################################

!! Please do read machtsinn.conf carefully before editing or using this script !!

###
## Whitelist usage
###

In /etc/machtsinn/whitelist.conf you can specifie one domain per line, which should never get blocked.
Please use this feature with care and do run some tests before putting it in a productive environment.

## Example entry in /etc/machtsinn/whitelist.conf

duckduckgo.com

This entry makes sure, duckduckgo.com and(!) www.duckduckgo.com never gets into your final blacklist.
All domains containig duckduckgo.com will also get unblocked at this point, resulting in fishing.duckduckgo.com.spammer.org
also getting removed from the final blacklist. Hopefully I can fix this in the near future.
