# M003.9 F5 counterclaim probe

Recorded before one provider-free probe, 2026-09-26 AEST. The default Tavily
F5 run used the false-premise wording ("Why does HTTPS ... prevent a website
from seeing my IP address?") and selected no passage that clearly established
what the destination receives. The [Proton HTTPS explainer](https://proton.me/learn/encryption/glossary/https)
contains a relevant VPN contrast, and [Mozilla's OHTTP explainer](https://support.mozilla.org/en-US/kb/ohttp-explained)
states that ordinary site requests include an IP address. Those sources are
research leads only; the app must independently fetch and store a passage
before citing it.

One bounded diagnostic: change only the web search text to the counterclaim
question `Does HTTPS hide your IP address from websites?` and the lexical
query to `websites see your IP address`. Keep the original F5 question, fetch
safety, source/passages caps, and no-provider mode unchanged. If no direct
correction survives retrieval, record that miss; do not weaken acquisition or
pretend that a server-IP passage answers the client-IP question.

## Result

The one Tavily retrieval completed in **4.79 s**, opening only Proton's HTTPS
page and selecting ten passages. Mozilla and APNIC links were refused as
`acquisition/redirect_loop`; the Stack Exchange link returned an HTTP-status
refusal, Instagram was refused by published robots policy, and a YouTube short
had no readable text. The selected Proton FAQ contrasts VPN with HTTPS and
mentions hiding an IP address from sites, but no selected quote directly says
that a destination website sees the client's connection IP under ordinary
HTTPS. The strict readiness check therefore still fails. A counterclaim query
alone is not a sufficient treatment, and no planner change or hosted answer
call is justified from this probe.
